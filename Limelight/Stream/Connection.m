//
//  Connection.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/19/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "Connection.h"
#import "Utils.h"

#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

#include "Limelight.h"
#include "opus_multistream.h"

@implementation Connection {
    SERVER_INFORMATION _serverInfo;
    STREAM_CONFIGURATION _streamConfig;
    CONNECTION_LISTENER_CALLBACKS _clCallbacks;
    DECODER_RENDERER_CALLBACKS _drCallbacks;
    AUDIO_RENDERER_CALLBACKS _arCallbacks;
    char _hostString[256];
    char _appVersionString[32];
    char _gfeVersionString[32];
}

static NSLock* initLock;
static OpusMSDecoder* opusDecoder;
static id<ConnectionCallbacks> _callbacks;
static int lastFrameNumber;
static int activeVideoFormat;
static video_stats_t currentVideoStats;
static video_stats_t lastVideoStats;
static NSLock* videoStatsLock;

#define OUTPUT_BUS 0

// My iPod touch 5th Generation seems to really require 80 ms
// of buffering to deliver glitch-free playback :(
// FIXME: Maybe we can use a smaller buffer on more modern iOS versions?
#define CIRCULAR_BUFFER_DURATION 80

static int audioBufferEntries;
static int audioBufferWriteIndex;
static int audioBufferReadIndex;
static int audioBufferStride;
static int audioSamplesPerFrame;
static short* audioCircularBuffer;

#define AUDIO_QUEUE_BUFFERS 3

static AudioQueueRef audioQueue;
static AudioQueueBufferRef audioBuffers[AUDIO_QUEUE_BUFFERS];
static VideoDecoderRenderer* renderer;

int DrDecoderSetup(int videoFormat, int width, int height, int redrawRate, void* context, int drFlags)
{
    [renderer setupWithVideoFormat:videoFormat refreshRate:redrawRate];
    lastFrameNumber = 0;
    activeVideoFormat = videoFormat;
    memset(&currentVideoStats, 0, sizeof(currentVideoStats));
    memset(&lastVideoStats, 0, sizeof(lastVideoStats));
    return 0;
}

void DrCleanup(void)
{
    [renderer cleanup];
}

-(BOOL) getVideoStats:(video_stats_t*)stats
{
    // We return lastVideoStats because it is a complete 1 second window
    [videoStatsLock lock];
    if (lastVideoStats.endTime != 0) {
        memcpy(stats, &lastVideoStats, sizeof(*stats));
        [videoStatsLock unlock];
        return YES;
    }
    
    // No stats yet
    [videoStatsLock unlock];
    return NO;
}

-(NSString*) getActiveCodecName
{
    switch (activeVideoFormat)
    {
        case VIDEO_FORMAT_H264:
            return @"H.264";
        case VIDEO_FORMAT_H265:
            return @"HEVC";
        case VIDEO_FORMAT_H265_MAIN10:
            return @"HEVC Main 10";
        default:
            return @"UNKNOWN";
    }
}

int DrSubmitDecodeUnit(PDECODE_UNIT decodeUnit)
{
    int offset = 0;
    int ret;
    unsigned char* data = (unsigned char*) malloc(decodeUnit->fullLength);
    if (data == NULL) {
        // A frame was lost due to OOM condition
        return DR_NEED_IDR;
    }
    
    CFTimeInterval now = CACurrentMediaTime();
    if (!lastFrameNumber) {
        currentVideoStats.startTime = now;
        lastFrameNumber = decodeUnit->frameNumber;
    }
    else {
        // Flip stats roughly every second
        if (now - currentVideoStats.startTime >= 1.0f) {
            currentVideoStats.endTime = now;
            
            [videoStatsLock lock];
            lastVideoStats = currentVideoStats;
            [videoStatsLock unlock];
            
            memset(&currentVideoStats, 0, sizeof(currentVideoStats));
            currentVideoStats.startTime = now;
        }
        
        // Any frame number greater than m_LastFrameNumber + 1 represents a dropped frame
        currentVideoStats.networkDroppedFrames += decodeUnit->frameNumber - (lastFrameNumber + 1);
        currentVideoStats.totalFrames += decodeUnit->frameNumber - (lastFrameNumber + 1);
        lastFrameNumber = decodeUnit->frameNumber;
    }
    
    currentVideoStats.receivedFrames++;
    currentVideoStats.totalFrames++;

    PLENTRY entry = decodeUnit->bufferList;
    while (entry != NULL) {
        // Submit parameter set NALUs directly since no copy is required by the decoder
        if (entry->bufferType != BUFFER_TYPE_PICDATA) {
            ret = [renderer submitDecodeBuffer:(unsigned char*)entry->data
                                        length:entry->length
                                    bufferType:entry->bufferType
                                           pts:decodeUnit->presentationTimeMs];
            if (ret != DR_OK) {
                free(data);
                return ret;
            }
        }
        else {
            memcpy(&data[offset], entry->data, entry->length);
            offset += entry->length;
        }

        entry = entry->next;
    }

    // This function will take our picture data buffer
    return [renderer submitDecodeBuffer:data
                                 length:offset
                             bufferType:BUFFER_TYPE_PICDATA
                                    pts:decodeUnit->presentationTimeMs];
}

int ArInit(int audioConfiguration, POPUS_MULTISTREAM_CONFIGURATION originalOpusConfig, void* context, int flags)
{
    int err;
    AudioChannelLayout channelLayout = {};
    OPUS_MULTISTREAM_CONFIGURATION opusConfig = *originalOpusConfig;
    
    // Initialize the circular buffer
    audioBufferWriteIndex = audioBufferReadIndex = 0;
    audioSamplesPerFrame = opusConfig.samplesPerFrame;
    audioBufferStride = opusConfig.channelCount * opusConfig.samplesPerFrame;
    audioBufferEntries = CIRCULAR_BUFFER_DURATION / (opusConfig.samplesPerFrame / (opusConfig.sampleRate / 1000));
    audioCircularBuffer = malloc(audioBufferEntries * audioBufferStride * sizeof(short));
    if (audioCircularBuffer == NULL) {
        Log(LOG_E, @"Error allocating output queue\n");
        return -1;
    }
    
    switch (opusConfig.channelCount) {
        case 2:
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
            break;
        case 4:
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Quadraphonic;
            break;
        case 6:
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_AudioUnit_5_1;
            break;
        case 8:
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_AudioUnit_7_1;
            
            // Swap SL/SR and RL/RR to match the selected channel layout
            opusConfig.mapping[4] = originalOpusConfig->mapping[6];
            opusConfig.mapping[5] = originalOpusConfig->mapping[7];
            opusConfig.mapping[6] = originalOpusConfig->mapping[4];
            opusConfig.mapping[7] = originalOpusConfig->mapping[5];
            break;
        default:
            // Unsupported channel layout
            Log(LOG_E, @"Unsupported channel layout: %d\n", opusConfig.channelCount);
            abort();
    }
    
    opusDecoder = opus_multistream_decoder_create(opusConfig.sampleRate,
                                                  opusConfig.channelCount,
                                                  opusConfig.streams,
                                                  opusConfig.coupledStreams,
                                                  opusConfig.mapping,
                                                  &err);

    // Configure the audio session for our app
    NSError *audioSessionError = nil;
    AVAudioSession* audioSession = [AVAudioSession sharedInstance];

    [audioSession setPreferredSampleRate:opusConfig.sampleRate error:&audioSessionError];
    [audioSession setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                        error:&audioSessionError];
    [audioSession setPreferredIOBufferDuration:(opusConfig.samplesPerFrame / (opusConfig.sampleRate / 1000)) / 1000.0
                                         error:&audioSessionError];
    [audioSession setActive: YES error: &audioSessionError];
    
    // FIXME: Calling this breaks surround audio for some reason
    //[audioSession setPreferredOutputNumberOfChannels:opusConfig->channelCount error:&audioSessionError];
    
    OSStatus status;
    
    AudioStreamBasicDescription audioFormat = {0};
    audioFormat.mSampleRate = opusConfig.sampleRate;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    audioFormat.mChannelsPerFrame = opusConfig.channelCount;
    audioFormat.mBytesPerFrame = audioFormat.mChannelsPerFrame * (audioFormat.mBitsPerChannel / 8);
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame;
    audioFormat.mFramesPerPacket = audioFormat.mBytesPerPacket / audioFormat.mBytesPerFrame;
    audioFormat.mReserved = 0;

    status = AudioQueueNewOutput(&audioFormat, FillOutputBuffer, nil, nil, nil, 0, &audioQueue);
    if (status != noErr) {
        Log(LOG_E, @"Error allocating output queue: %d\n", status);
        return status;
    }
    
    // We need to specify a channel layout for surround sound configurations
    status = AudioQueueSetProperty(audioQueue, kAudioQueueProperty_ChannelLayout, &channelLayout, sizeof(channelLayout));
    if (status != noErr) {
        Log(LOG_E, @"Error configuring surround channel layout: %d\n", status);
        return status;
    }
    
    for (int i = 0; i < AUDIO_QUEUE_BUFFERS; i++) {
        status = AudioQueueAllocateBuffer(audioQueue, audioFormat.mBytesPerFrame * opusConfig.samplesPerFrame, &audioBuffers[i]);
        if (status != noErr) {
            Log(LOG_E, @"Error allocating output buffer: %d\n", status);
            return status;
        }
        
        FillOutputBuffer(nil, audioQueue, audioBuffers[i]);
    }
    
    status = AudioQueueStart(audioQueue, nil);
    if (status != noErr) {
        Log(LOG_E, @"Error starting queue: %d\n", status);
        return status;
    }
    
    return status;
}

void ArCleanup(void)
{
    if (opusDecoder != NULL) {
        opus_multistream_decoder_destroy(opusDecoder);
        opusDecoder = NULL;
    }
    
    // Stop before disposing to avoid massive delay inside
    // AudioQueueDispose() (iOS bug?)
    AudioQueueStop(audioQueue, true);
    
    // Also frees buffers
    AudioQueueDispose(audioQueue, true);
    
    // Must be freed after the queue is stopped
    if (audioCircularBuffer != NULL) {
        free(audioCircularBuffer);
        audioCircularBuffer = NULL;
    }
    
    // Audio session is now inactive
    [[AVAudioSession sharedInstance] setActive: NO error: nil];
}

void ArDecodeAndPlaySample(char* sampleData, int sampleLength)
{
    int decodeLen;
    
    // Check if there is space for this sample in the buffer. Again, this can race
    // but in the worst case, we'll not see the sample callback having consumed a sample.
    if (((audioBufferWriteIndex + 1) % audioBufferEntries) == audioBufferReadIndex) {
        return;
    }
    
    decodeLen = opus_multistream_decode(opusDecoder, (unsigned char *)sampleData, sampleLength,
                                        (short*)&audioCircularBuffer[audioBufferWriteIndex * audioBufferStride], audioSamplesPerFrame, 0);
    if (decodeLen > 0) {
        // Use a full memory barrier to ensure the circular buffer is written before incrementing the index
        __sync_synchronize();
        
        // This can race with the reader in the sample callback, however this is a benign
        // race since we'll either read the original value of s_WriteIndex (which is safe,
        // we just won't consider this sample) or the new value of s_WriteIndex
        audioBufferWriteIndex = (audioBufferWriteIndex + 1) % audioBufferEntries;
    }
}

void ClStageStarting(int stage)
{
    [_callbacks stageStarting:LiGetStageName(stage)];
}

void ClStageComplete(int stage)
{
    [_callbacks stageComplete:LiGetStageName(stage)];
}

void ClStageFailed(int stage, int errorCode)
{
    [_callbacks stageFailed:LiGetStageName(stage) withError:errorCode portTestFlags:LiGetPortFlagsFromStage(stage)];
}

void ClConnectionStarted(void)
{
    [_callbacks connectionStarted];
}

void ClConnectionTerminated(int errorCode)
{
    [_callbacks connectionTerminated: errorCode];
}

void ClLogMessage(const char* format, ...)
{
    va_list va;
    va_start(va, format);
    vfprintf(stderr, format, va);
    va_end(va);
}

void ClRumble(unsigned short controllerNumber, unsigned short lowFreqMotor, unsigned short highFreqMotor)
{
    [_callbacks rumble:controllerNumber lowFreqMotor:lowFreqMotor highFreqMotor:highFreqMotor];
}

void ClConnectionStatusUpdate(int status)
{
    [_callbacks connectionStatusUpdate:status];
}

-(void) terminate
{
    // Interrupt any action blocking LiStartConnection(). This is
    // thread-safe and done outside initLock on purpose, since we
    // won't be able to acquire it if LiStartConnection is in
    // progress.
    LiInterruptConnection();
    
    // We dispatch this async to get out because this can be invoked
    // on a thread inside common and we don't want to deadlock. It also avoids
    // blocking on the caller's thread waiting to acquire initLock.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [initLock lock];
        LiStopConnection();
        [initLock unlock];
    });
}

-(id) initWithConfig:(StreamConfiguration*)config renderer:(VideoDecoderRenderer*)myRenderer connectionCallbacks:(id<ConnectionCallbacks>)callbacks
{
    self = [super init];

    // Use a lock to ensure that only one thread is initializing
    // or deinitializing a connection at a time.
    if (initLock == nil) {
        initLock = [[NSLock alloc] init];
    }
    
    if (videoStatsLock == nil) {
        videoStatsLock = [[NSLock alloc] init];
    }
    
    strncpy(_hostString,
            [config.host cStringUsingEncoding:NSUTF8StringEncoding],
            sizeof(_hostString));
    strncpy(_appVersionString,
            [config.appVersion cStringUsingEncoding:NSUTF8StringEncoding],
            sizeof(_appVersionString));
    if (config.gfeVersion != nil) {
        strncpy(_gfeVersionString,
                [config.gfeVersion cStringUsingEncoding:NSUTF8StringEncoding],
                sizeof(_gfeVersionString));
    }

    LiInitializeServerInformation(&_serverInfo);
    _serverInfo.address = _hostString;
    _serverInfo.serverInfoAppVersion = _appVersionString;
    if (config.gfeVersion != nil) {
        _serverInfo.serverInfoGfeVersion = _gfeVersionString;
    }

    renderer = myRenderer;
    _callbacks = callbacks;

    LiInitializeStreamConfiguration(&_streamConfig);
    _streamConfig.width = config.width;
    _streamConfig.height = config.height;
    _streamConfig.fps = config.frameRate;
    _streamConfig.bitrate = config.bitRate;
    _streamConfig.enableHdr = config.enableHdr;
    _streamConfig.audioConfiguration = config.audioConfiguration;
    
    // TODO: If/when video encryption is added, we'll probably want to
    // limit that to devices that support the ARMv8 AES instructions.
    _streamConfig.encryptionFlags = ENCFLG_AUDIO;
    
    // Use some of the HEVC encoding efficiency improvements to
    // reduce bandwidth usage while still gaining some image
    // quality improvement.
    _streamConfig.hevcBitratePercentageMultiplier = 75;
    
    if ([Utils isActiveNetworkVPN]) {
        // Force remote streaming mode when a VPN is connected
        _streamConfig.streamingRemotely = STREAM_CFG_REMOTE;
        _streamConfig.packetSize = 1024;
    }
    else {
        // Detect remote streaming automatically based on the IP address of the target
        _streamConfig.streamingRemotely = STREAM_CFG_AUTO;
        _streamConfig.packetSize = 1392;
    }
    
    // HDR implies HEVC allowed
    if (config.enableHdr) {
        config.allowHevc = YES;
    }
    
    // Streaming at resolutions above 4K requires HEVC
    if (config.width > 4096 || config.height > 4096) {
        config.allowHevc = YES;
    }

    // On iOS 11, we can use HEVC if the server supports encoding it
    // and this device has hardware decode for it (A9 and later).
    // Additionally, iPhone X had a bug which would cause video
    // to freeze after a few minutes with HEVC prior to iOS 11.3.
    // As a result, we will only use HEVC on iOS 11.3 or later.
    if (@available(iOS 11.3, tvOS 11.3, *)) {
        _streamConfig.supportsHevc =
#if !TARGET_OS_TV
            config.allowHevc &&
#endif
            VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
    }
    
    // HEVC must be supported when HDR is enabled
    assert(!_streamConfig.enableHdr || _streamConfig.supportsHevc);

    memcpy(_streamConfig.remoteInputAesKey, [config.riKey bytes], [config.riKey length]);
    memset(_streamConfig.remoteInputAesIv, 0, 16);
    int riKeyId = htonl(config.riKeyId);
    memcpy(_streamConfig.remoteInputAesIv, &riKeyId, sizeof(riKeyId));

    LiInitializeVideoCallbacks(&_drCallbacks);
    _drCallbacks.setup = DrDecoderSetup;
    _drCallbacks.cleanup = DrCleanup;
    _drCallbacks.submitDecodeUnit = DrSubmitDecodeUnit;

    // RFI doesn't work properly with HEVC on iOS 11 with an iPhone SE (at least)
    // It doesnt work on macOS either, tested with Network Link Conditioner.
    // RFI seems to be broken at all resolutions on the Apple TV 4K (1st gen)
    // on tvOS 14.5.
    _drCallbacks.capabilities =
#if !TARGET_OS_TV
                                CAPABILITY_REFERENCE_FRAME_INVALIDATION_AVC |
#endif
                                CAPABILITY_DIRECT_SUBMIT;

    LiInitializeAudioCallbacks(&_arCallbacks);
    _arCallbacks.init = ArInit;
    _arCallbacks.cleanup = ArCleanup;
    _arCallbacks.decodeAndPlaySample = ArDecodeAndPlaySample;
    _arCallbacks.capabilities = CAPABILITY_DIRECT_SUBMIT |
                                CAPABILITY_SUPPORTS_ARBITRARY_AUDIO_DURATION;

    LiInitializeConnectionCallbacks(&_clCallbacks);
    _clCallbacks.stageStarting = ClStageStarting;
    _clCallbacks.stageComplete = ClStageComplete;
    _clCallbacks.stageFailed = ClStageFailed;
    _clCallbacks.connectionStarted = ClConnectionStarted;
    _clCallbacks.connectionTerminated = ClConnectionTerminated;
    _clCallbacks.logMessage = ClLogMessage;
    _clCallbacks.rumble = ClRumble;
    _clCallbacks.connectionStatusUpdate = ClConnectionStatusUpdate;

    return self;
}

static void FillOutputBuffer(void *aqData,
                             AudioQueueRef inAQ,
                             AudioQueueBufferRef inBuffer) {
    inBuffer->mAudioDataByteSize = audioBufferStride * sizeof(short);
    
    assert(inBuffer->mAudioDataByteSize == inBuffer->mAudioDataBytesCapacity);
    
    // If the indexes aren't equal, we have a sample
    if (audioBufferWriteIndex != audioBufferReadIndex) {
        // Copy data to the audio buffer
        memcpy(inBuffer->mAudioData,
               &audioCircularBuffer[audioBufferReadIndex * audioBufferStride],
               inBuffer->mAudioDataByteSize);
        
        // Use a full memory barrier to ensure the circular buffer is read before incrementing the index
        __sync_synchronize();
        
        // This can race with the reader in the AudDecDecodeAndPlaySample function. This is
        // not a problem because at worst, it just won't see that we've consumed this sample yet.
        audioBufferReadIndex = (audioBufferReadIndex + 1) % audioBufferEntries;
    }
    else {
        // No data, so play silence
        memset(inBuffer->mAudioData, 0, inBuffer->mAudioDataByteSize);
    }
    
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

-(void) main
{
    [initLock lock];
    LiStartConnection(&_serverInfo,
                      &_streamConfig,
                      &_clCallbacks,
                      &_drCallbacks,
                      &_arCallbacks,
                      NULL, 0,
                      NULL, 0);
    [initLock unlock];
}

@end
