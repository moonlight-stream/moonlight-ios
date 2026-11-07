#import "NativeAppleMic.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <stdatomic.h>
#include "Limelight.h"
#include "NativeMicEncoder.h"

@implementation NativeAppleMic {
    AudioQueueRef _queue;
    dispatch_queue_t _captureQueue;
    NATIVE_MIC_SENDER* _sender;
    OpusEncoder* _encoder;
    int16_t _frame[NATIVE_MIC_FRAME_SAMPLES];
    size_t _filled;
    atomic_bool _active;
    BOOL _duplex;
}

- (BOOL)startWhileAllowed:(BOOL (^)(void))allowed onFailure:(void (^)(void))failure
{
    atomic_init(&_active, false);
    if (@available(iOS 17.0, tvOS 17.0, *)) {
        if (AVAudioApplication.sharedInstance.recordPermission != AVAudioApplicationRecordPermissionGranted ||
            !allowed()) {
            return NO;
        }
    } else {
        return NO;
    }

    _sender = LiCreateNativeMicSender();
    if (!_sender) {
        return NO;
    }
    _encoder = NativeMicEncoderCreate();
    AVAudioSession* session = AVAudioSession.sharedInstance;
    if (!_encoder || ![session setCategory:AVAudioSessionCategoryPlayAndRecord
                                      mode:AVAudioSessionModeVoiceChat
                                   options:AVAudioSessionCategoryOptionMixWithOthers error:NULL]) {
        [self stop];
        return NO;
    }
    _duplex = YES;
    if (!session.isInputAvailable || !allowed()) {
        [self stop];
        return NO;
    }

    AudioStreamBasicDescription format = {
        .mSampleRate = NATIVE_MIC_SAMPLE_RATE,
        .mFormatID = kAudioFormatLinearPCM,
        .mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
        .mBytesPerPacket = sizeof(int16_t),
        .mFramesPerPacket = 1,
        .mBytesPerFrame = sizeof(int16_t),
        .mChannelsPerFrame = 1,
        .mBitsPerChannel = 16,
    };
    _captureQueue = dispatch_queue_create("org.moonlight.native-mic", DISPATCH_QUEUE_SERIAL);
    __weak NativeAppleMic* weakSelf = self;
    OSStatus error = AudioQueueNewInputWithDispatchQueue(&_queue, &format, 0, _captureQueue,
        ^(AudioQueueRef queue, AudioQueueBufferRef buffer, const AudioTimeStamp* time,
          UInt32 packetCount, const AudioStreamPacketDescription* descriptions) {
            (void)time;
            (void)packetCount;
            (void)descriptions;
            NativeAppleMic* mic = weakSelf;
            if (!mic || !atomic_load(&mic->_active) || !allowed()) {
                return;
            }
            if (![mic sendBuffer:buffer whileAllowed:allowed] ||
                AudioQueueEnqueueBuffer(queue, buffer, 0, NULL) != noErr) {
                atomic_store(&mic->_active, false);
                failure();
            }
        });
    for (int i = 0; error == noErr && i < 4; i++) {
        AudioQueueBufferRef buffer;
        error = AudioQueueAllocateBuffer(_queue, sizeof(_frame), &buffer);
        if (error == noErr) {
            error = AudioQueueEnqueueBuffer(_queue, buffer, 0, NULL);
        }
    }
    if (error == noErr && allowed()) {
        atomic_store(&_active, true);
        if (AudioQueueStart(_queue, NULL) == noErr) {
            return YES;
        }
    }
    [self stop];
    return NO;
}

- (BOOL)sendBuffer:(AudioQueueBufferRef)buffer whileAllowed:(BOOL (^)(void))allowed
{
    if (buffer->mAudioDataByteSize > buffer->mAudioDataBytesCapacity ||
        buffer->mAudioDataByteSize % sizeof(int16_t) != 0) {
        return NO;
    }
    const int16_t* pcm = buffer->mAudioData;
    for (size_t i = 0; i < buffer->mAudioDataByteSize / sizeof(*pcm); i++) {
        _frame[_filled++] = pcm[i];
        if (_filled == NATIVE_MIC_FRAME_SAMPLES) {
            unsigned char packet[NATIVE_MIC_FRAME_BYTES];
            if (!atomic_load(&_active) || !allowed() ||
                NativeMicEncode(_encoder, _frame, _filled, packet, sizeof(packet)) != OPUS_OK ||
                LiSendNativeMicFrame(_sender, packet, sizeof(packet)) != 0) {
                return NO;
            }
            _filled = 0;
        }
    }
    return YES;
}

- (void)stop
{
    atomic_store(&_active, false);
    if (_queue) {
        AudioQueueStop(_queue, true);
        AudioQueueDispose(_queue, true);
        _queue = NULL;
    }
    if (_captureQueue) {
        dispatch_sync(_captureQueue, ^{});
        _captureQueue = nil;
    }
    if (_sender) {
        LiDestroyNativeMicSender(_sender);
        _sender = NULL;
    }
    if (_encoder) {
        opus_encoder_destroy(_encoder);
        _encoder = NULL;
    }
    if (_duplex) {
        [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback
                                       withOptions:AVAudioSessionCategoryOptionMixWithOthers error:NULL];
        _duplex = NO;
    }
}

@end
