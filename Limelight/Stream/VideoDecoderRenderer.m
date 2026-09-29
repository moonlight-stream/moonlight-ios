//
//  VideoDecoderRenderer.m
//  Moonlight
//
//  Created by Cameron Gutman on 10/18/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "VideoDecoderRenderer.h"
#import "StreamView.h"
#import "VideoSuperResolution.h"

@import VideoToolbox;

#include <libavcodec/avcodec.h>
#include <libavcodec/cbs.h>
#include <libavcodec/cbs_av1.h>
#include <libavformat/avio.h>
#include <libavutil/mem.h>

// Private libavformat API for writing the AV1 Codec Configuration Box
extern int ff_isom_write_av1c(AVIOContext *pb, const uint8_t *buf, int size,
                              int write_seq_header);

static const void* kVideoSuperResolutionQueueKey = &kVideoSuperResolutionQueueKey;

@implementation VideoDecoderRenderer {
    StreamView* _view;
    id<ConnectionCallbacks> _callbacks;
    float _streamAspectRatio;
    
    AVSampleBufferDisplayLayer* displayLayer;
    int videoFormat;
    int frameRate;
    int videoWidth;
    int videoHeight;
    
    NSMutableArray *parameterSetBuffers;
    NSData *masteringDisplayColorVolume;
    NSData *contentLightLevelInfo;
    CMVideoFormatDescriptionRef formatDesc;
    VideoSuperResolution* _videoSuperResolution;
    BOOL _useVideoSuperResolution;
    BOOL _videoSuperResolutionHdrEnabled;
    dispatch_queue_t _videoSuperResolutionQueue;
    VTDecompressionSessionRef _decompressionSession;
    CGSize _videoSuperResolutionTargetSize;
    
    CADisplayLink* _displayLink;
    BOOL framePacing;
}

- (void)reinitializeDisplayLayer
{
    CALayer *oldLayer = displayLayer;
    
    displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    displayLayer.backgroundColor = [UIColor blackColor].CGColor;
    
    // Ensure the AVSampleBufferDisplayLayer is sized to preserve the aspect ratio
    // of the video stream. We used to use AVLayerVideoGravityResizeAspect, but that
    // respects the PAR encoded in the SPS which causes our computed video-relative
    // touch location to be wrong in StreamView if the aspect ratio of the host
    // desktop doesn't match the aspect ratio of the stream.
    CGSize videoSize;
    if (_view.bounds.size.width > _view.bounds.size.height * _streamAspectRatio) {
        videoSize = CGSizeMake(_view.bounds.size.height * _streamAspectRatio, _view.bounds.size.height);
    } else {
        videoSize = CGSizeMake(_view.bounds.size.width, _view.bounds.size.width / _streamAspectRatio);
    }
    displayLayer.position = CGPointMake(CGRectGetMidX(_view.bounds), CGRectGetMidY(_view.bounds));
    displayLayer.bounds = CGRectMake(0, 0, videoSize.width, videoSize.height);
    displayLayer.videoGravity = AVLayerVideoGravityResize;

    // Hide the layer until we get an IDR frame. This ensures we
    // can see the loading progress label as the stream is starting.
    displayLayer.hidden = YES;
    
    if (oldLayer != nil) {
        // Switch out the old display layer with the new one
        [_view.layer replaceSublayer:oldLayer with:displayLayer];
    }
    else {
        [_view.layer addSublayer:displayLayer];
    }
    
    if (formatDesc != nil) {
        CFRelease(formatDesc);
        formatDesc = nil;
    }
}

- (id)initWithView:(StreamView*)view callbacks:(id<ConnectionCallbacks>)callbacks streamAspectRatio:(float)aspectRatio useFramePacing:(BOOL)useFramePacing
{
    self = [super init];
    
    _view = view;
    _callbacks = callbacks;
    _streamAspectRatio = aspectRatio;
    framePacing = useFramePacing;
    _useVideoSuperResolution = [[NSUserDefaults standardUserDefaults] boolForKey:@"videoSuperResolution"];
    
    parameterSetBuffers = [[NSMutableArray alloc] init];
    if (_useVideoSuperResolution) {
        _videoSuperResolution = [[VideoSuperResolution alloc] init];
        // Build the long-lived GPU state once up front. Size-dependent resources are configured later.
        [_videoSuperResolution initializeResources];
        [_videoSuperResolution setHdrEnabled:NO];

        // Keep the optional VSR decode/conversion path off the main thread.
        _videoSuperResolutionQueue = dispatch_queue_create("com.moonlight.VideoSuperResolution", DISPATCH_QUEUE_SERIAL);

        // Tag the queue so we can safely invalidate the VT session from either the queue itself
        // or another thread without introducing a cross-thread lifetime bug.
        dispatch_queue_set_specific(_videoSuperResolutionQueue, kVideoSuperResolutionQueueKey, (void*)kVideoSuperResolutionQueueKey, NULL);
    }
    
    [self reinitializeDisplayLayer];
    
    return self;
}

- (CGSize)videoSuperResolutionTargetSize
{
    __block CGRect displayBounds = CGRectZero;
    __block CGFloat screenScale = 1.0;
    void (^readUIState)(void) = ^{
        UIScreen* screen = self->_view.window.screen ?: UIScreen.mainScreen;

        // The display layer bounds define the actual presentation size after aspect-ratio fitting.
        displayBounds = self->displayLayer.bounds;
        screenScale = screen.nativeScale > 0.0 ? screen.nativeScale : screen.scale;
    };
    
    if ([NSThread isMainThread]) {
        readUIState();
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), readUIState);
    }
    
    return CGSizeMake(MAX(1.0, CGRectGetWidth(displayBounds) * screenScale),
                      MAX(1.0, CGRectGetHeight(displayBounds) * screenScale));
}

- (void)invalidateVideoSuperResolutionDecoder
{
    if (_videoSuperResolutionQueue == NULL) {
        if (_decompressionSession != NULL) {
            VTDecompressionSessionInvalidate(_decompressionSession);
            CFRelease(_decompressionSession);
            _decompressionSession = NULL;
        }
        return;
    }

    // The decompression session is owned by the VSR queue, so all invalidation must run there.
    void (^invalidateBlock)(void) = ^{
        if (self->_decompressionSession != NULL) {
            VTDecompressionSessionInvalidate(self->_decompressionSession);
            CFRelease(self->_decompressionSession);
            self->_decompressionSession = NULL;
        }
    };

    if (dispatch_get_specific(kVideoSuperResolutionQueueKey) == kVideoSuperResolutionQueueKey) {
        invalidateBlock();
    }
    else {
        dispatch_sync(_videoSuperResolutionQueue, invalidateBlock);
    }
}

- (BOOL)setupVideoSuperResolutionDecoder
{
    if (!_useVideoSuperResolution || formatDesc == NULL) {
        return NO;
    }

    // Rebuild the secondary decode session when the stream format or HDR mode changes.
    [self invalidateVideoSuperResolutionDecoder];

    NSDictionary* imageBufferAttributes = @{
        // Request a Metal-compatible decoder output so VideoSuperResolution can wrap it directly
        // as a CVMetalTexture without an extra CPU copy.
        (id)kCVPixelBufferPixelFormatTypeKey : @(_videoSuperResolutionHdrEnabled ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferMetalCompatibilityKey : @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    };

    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                   formatDesc,
                                                   NULL,
                                                   (__bridge CFDictionaryRef)imageBufferAttributes,
                                                   NULL,
                                                   &_decompressionSession);
    if (status != noErr || _decompressionSession == NULL) {
        Log(LOG_E, @"Failed to create VideoSuperResolution decompression session: %d", (int)status);
        [self invalidateVideoSuperResolutionDecoder];
        return NO;
    }

    return YES;
}

- (BOOL)enqueueVideoSuperResolutionSampleBuffer:(CMSampleBufferRef)sampleBuffer decodeUnit:(PDECODE_UNIT)du
{
    BOOL isIDRFrame = du->frameType == FRAME_TYPE_IDR;
    CFRetain(sampleBuffer);
    
    dispatch_async(_videoSuperResolutionQueue, ^{
        @autoreleasepool {
            // Lazily create the secondary VT session on the queue that will own and use it.
            if (self->_decompressionSession == NULL && ![self setupVideoSuperResolutionDecoder]) {
                CFRelease(sampleBuffer);
                return;
            }

            __block CMSampleBufferRef rgbSampleBuffer = NULL;
            __block BOOL decodeCompleted = NO;
            VTDecodeInfoFlags infoFlags = 0;
            
            // Decode into a Metal-compatible pixel buffer, then hand that image buffer to the
            // VSR path for YUV->RGB conversion and optional MetalFX scaling.
            OSStatus status = VTDecompressionSessionDecodeFrameWithOutputHandler(self->_decompressionSession,
                                                                                 sampleBuffer,
                                                                                 0,
                                                                                 &infoFlags,
                                                                                 ^(OSStatus decodeStatus,
                                                                                   VTDecodeInfoFlags decodeInfoFlags,
                                                                                   CVImageBufferRef  _Nullable imageBuffer,
                                                                                   CMTime presentationTimeStamp,
                                                                                   CMTime presentationDuration) {
                decodeCompleted = YES;

                if (decodeStatus != noErr || imageBuffer == nil) {
                    Log(LOG_E, @"VideoSuperResolution decode failed: %d flags: %u", (int)decodeStatus, (unsigned int)decodeInfoFlags);
                    return;
                }

                // The source sample buffer is passed through so the RGB output can inherit its
                // HDR and color attachments before it is enqueued for display.
                rgbSampleBuffer = [self->_videoSuperResolution copyRGBSampleBufferFromImageBuffer:imageBuffer
                                                                                 sourceSampleBuffer:sampleBuffer
                                                                             presentationTimeStamp:presentationTimeStamp
                                                                                          duration:presentationDuration];
            });
            
            CFRelease(sampleBuffer);
            
            if (status != noErr) {
                Log(LOG_E, @"VTDecompressionSessionDecodeFrame failed: %d", (int)status);
                [self invalidateVideoSuperResolutionDecoder];
                return;
            }

            if (!decodeCompleted || rgbSampleBuffer == NULL) {
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // AVSampleBufferDisplayLayer remains a main-thread-facing object even though
                // decoding and conversion happen on the dedicated VSR queue.
                [self->displayLayer enqueueSampleBuffer:rgbSampleBuffer];

                if (isIDRFrame) {
                    self->displayLayer.hidden = NO;
                    [self->_callbacks videoContentShown];
                }
                
                CFRelease(rgbSampleBuffer);
            });
        }
    });
    
    return YES;
}

- (void)setupWithVideoFormat:(int)videoFormat width:(int)videoWidth height:(int)videoHeight frameRate:(int)frameRate
{
    self->videoFormat = videoFormat;
    self->videoWidth = videoWidth;
    self->videoHeight = videoHeight;
    self->frameRate = frameRate;
    
    if (_useVideoSuperResolution) {
        _videoSuperResolutionTargetSize = [self videoSuperResolutionTargetSize];
        [_videoSuperResolution setHdrEnabled:_videoSuperResolutionHdrEnabled];
        if (![_videoSuperResolution configureWithInputSize:CGSizeMake(self->videoWidth, self->videoHeight)
                                                outputSize:_videoSuperResolutionTargetSize]) {
            Log(LOG_W, @"VideoSuperResolution session resource configuration failed");
        }
    }
}

- (void)start
{
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    if (@available(iOS 15.0, tvOS 15.0, *)) {
        _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(self->frameRate, self->frameRate, self->frameRate);
    }
    else {
        _displayLink.preferredFramesPerSecond = self->frameRate;
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

// TODO: Refactor this
int DrSubmitDecodeUnit(PDECODE_UNIT decodeUnit);

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    VIDEO_FRAME_HANDLE handle;
    PDECODE_UNIT du;
    
    while (LiPollNextVideoFrame(&handle, &du)) {
        LiCompleteVideoFrame(handle, DrSubmitDecodeUnit(du));
        
        if (framePacing) {
            // Calculate the actual display refresh rate
            double displayRefreshRate = 1 / (_displayLink.targetTimestamp - _displayLink.timestamp);
            
            // Only pace frames if the display refresh rate is >= 90% of our stream frame rate.
            // Battery saver, accessibility settings, or device thermals can cause the actual
            // refresh rate of the display to drop below the physical maximum.
            if (displayRefreshRate >= frameRate * 0.9f) {
                // Keep one pending frame to smooth out gaps due to
                // network jitter at the cost of 1 frame of latency
                if (LiGetPendingVideoFrames() == 1) {
                    break;
                }
            }
        }
    }
}

- (void)stop
{
    if (_videoSuperResolutionQueue != NULL) {
        dispatch_sync(_videoSuperResolutionQueue, ^{
        });
    }
    
    [self invalidateVideoSuperResolutionDecoder];
    [_displayLink invalidate];
}

#define NALU_START_PREFIX_SIZE 3
#define NAL_LENGTH_PREFIX_SIZE 4

- (void)updateAnnexBBufferForRange:(CMBlockBufferRef)frameBuffer dataBlock:(CMBlockBufferRef)dataBuffer offset:(int)offset length:(int)nalLength
{
    OSStatus status;
    size_t oldOffset = CMBlockBufferGetDataLength(frameBuffer);
    
    // Append a 4 byte buffer to the frame block for the length prefix
    status = CMBlockBufferAppendMemoryBlock(frameBuffer, NULL,
                                            NAL_LENGTH_PREFIX_SIZE,
                                            kCFAllocatorDefault, NULL, 0,
                                            NAL_LENGTH_PREFIX_SIZE, 0);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferAppendMemoryBlock failed: %d", (int)status);
        return;
    }
    
    // Write the length prefix to the new buffer
    const int dataLength = nalLength - NALU_START_PREFIX_SIZE;
    const uint8_t lengthBytes[] = {(uint8_t)(dataLength >> 24), (uint8_t)(dataLength >> 16),
        (uint8_t)(dataLength >> 8), (uint8_t)dataLength};
    status = CMBlockBufferReplaceDataBytes(lengthBytes, frameBuffer,
                                           oldOffset, NAL_LENGTH_PREFIX_SIZE);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferReplaceDataBytes failed: %d", (int)status);
        return;
    }
    
    // Attach the data buffer to the frame buffer by reference
    status = CMBlockBufferAppendBufferReference(frameBuffer, dataBuffer, offset + NALU_START_PREFIX_SIZE, dataLength, 0);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferAppendBufferReference failed: %d", (int)status);
        return;
    }
}

- (NSData*)getAv1CodecConfigurationBox:(NSData*)frameData  {
    AVIOContext* ioctx = NULL;
    int err;
    
    err = avio_open_dyn_buf(&ioctx);
    if (err < 0) {
        Log(LOG_E, @"avio_open_dyn_buf() failed: %d", err);
        return nil;
    }

    // Submit the IDR frame to write the av1C blob
    err = ff_isom_write_av1c(ioctx, (uint8_t*)frameData.bytes, (int)frameData.length, 1);
    if (err < 0) {
        Log(LOG_E, @"ff_isom_write_av1c() failed: %d", err);
        // Fall-through to close and free buffer
    }
    
    // Close the dynbuf and get the underlying buffer back (which we must free)
    uint8_t* av1cBuf = NULL;
    int av1cBufLen = avio_close_dyn_buf(ioctx, &av1cBuf);
    
    Log(LOG_I, @"av1C block is %d bytes", av1cBufLen);
    
    // Only return data if ff_isom_write_av1c() was successful
    NSData* data = nil;
    if (err >= 0 && av1cBufLen > 0) {
        data = [NSData dataWithBytes:av1cBuf length:av1cBufLen];
    }
    else {
        data = nil;
    }
    
    av_free(av1cBuf);
    return data;
}

// Much of this logic comes from Chrome
- (CMVideoFormatDescriptionRef)createAV1FormatDescriptionForIDRFrame:(NSData*)frameData {
    NSMutableDictionary* extensions = [[NSMutableDictionary alloc] init];

    CodedBitstreamContext* cbsCtx = NULL;
    int err = ff_cbs_init(&cbsCtx, AV_CODEC_ID_AV1, NULL);
    if (err < 0) {
        Log(LOG_E, @"ff_cbs_init() failed: %d", err);
        return nil;
    }
    
    AVPacket avPacket = {};
    avPacket.data = (uint8_t*)frameData.bytes;
    avPacket.size = (int)frameData.length;
    
    // Read the sequence header OBU
    CodedBitstreamFragment cbsFrag = {};
    err = ff_cbs_read_packet(cbsCtx, &cbsFrag, &avPacket);
    if (err < 0) {
        Log(LOG_E, @"ff_cbs_read_packet() failed: %d", err);
        ff_cbs_close(&cbsCtx);
        return nil;
    }
    
#define SET_CFSTR_EXTENSION(key, value) extensions[(__bridge NSString*)key] = (__bridge NSString*)(value)
#define SET_EXTENSION(key, value) extensions[(__bridge NSString*)key] = (value)

    SET_EXTENSION(kCMFormatDescriptionExtension_FormatName, @"av01");
    
    // We use the value for YUV without alpha, same as Chrome
    // https://developer.apple.com/library/archive/qa/qa1183/_index.html
    SET_EXTENSION(kCMFormatDescriptionExtension_Depth, @24);
    
    CodedBitstreamAV1Context* bitstreamCtx = (CodedBitstreamAV1Context*)cbsCtx->priv_data;
    AV1RawSequenceHeader* seqHeader = bitstreamCtx->sequence_header;
    if (seqHeader == NULL) {
        Log(LOG_E, @"AV1 sequence header not found in IDR frame!");
        ff_cbs_fragment_free(&cbsFrag);
        ff_cbs_close(&cbsCtx);
        return nil;
    }
    
    switch (seqHeader->color_config.color_primaries) {
        case 1: // CP_BT_709
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ColorPrimaries,
                                kCMFormatDescriptionColorPrimaries_ITU_R_709_2);
            break;
            
        case 6: // CP_BT_601
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ColorPrimaries,
                                kCMFormatDescriptionColorPrimaries_SMPTE_C);
            break;
            
        case 9: // CP_BT_2020
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ColorPrimaries,
                                kCMFormatDescriptionColorPrimaries_ITU_R_2020);
            break;
            
        default:
            Log(LOG_W, @"Unsupported color_primaries value: %d", seqHeader->color_config.color_primaries);
            break;
    }
    
    switch (seqHeader->color_config.transfer_characteristics) {
        case 1: // TC_BT_709
        case 6: // TC_BT_601
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_ITU_R_709_2);
            break;
            
        case 7: // TC_SMPTE_240
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_SMPTE_240M_1995);
            break;
            
        case 8: // TC_LINEAR
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_Linear);
            break;
            
        case 14: // TC_BT_2020_10_BIT
        case 15: // TC_BT_2020_12_BIT
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_ITU_R_2020);
            break;
            
        case 16: // TC_SMPTE_2084
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ);
            break;
            
        case 17: // TC_HLG
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_TransferFunction,
                                kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG);
            break;
            
        default:
            Log(LOG_W, @"Unsupported transfer_characteristics value: %d", seqHeader->color_config.transfer_characteristics);
            break;
    }
    
    switch (seqHeader->color_config.matrix_coefficients) {
        case 1: // MC_BT_709
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2);
            break;
            
        case 6: // MC_BT_601
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_ITU_R_601_4);
            break;
            
        case 7: // MC_SMPTE_240
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_SMPTE_240M_1995);
            break;
            
        case 9: // MC_BT_2020_NCL
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_YCbCrMatrix,
                                kCMFormatDescriptionYCbCrMatrix_ITU_R_2020);
            break;
            
        default:
            Log(LOG_W, @"Unsupported matrix_coefficients value: %d", seqHeader->color_config.matrix_coefficients);
            break;
    }
    
    SET_EXTENSION(kCMFormatDescriptionExtension_FullRangeVideo, @(seqHeader->color_config.color_range == 1));
    
    // Progressive content
    SET_EXTENSION(kCMFormatDescriptionExtension_FieldCount, @(1));
    
    switch (seqHeader->color_config.chroma_sample_position) {
        case 1: // CSP_VERTICAL
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ChromaLocationTopField,
                                kCMFormatDescriptionChromaLocation_Left);
            break;
            
        case 2: // CSP_COLOCATED
            SET_CFSTR_EXTENSION(kCMFormatDescriptionExtension_ChromaLocationTopField,
                                kCMFormatDescriptionChromaLocation_TopLeft);
            break;
            
        default:
            Log(LOG_W, @"Unsupported chroma_sample_position value: %d", seqHeader->color_config.chroma_sample_position);
            break;
    }
    
    if (contentLightLevelInfo) {
        SET_EXTENSION(kCMFormatDescriptionExtension_ContentLightLevelInfo, contentLightLevelInfo);
    }
    
    if (masteringDisplayColorVolume) {
        SET_EXTENSION(kCMFormatDescriptionExtension_MasteringDisplayColorVolume, masteringDisplayColorVolume);
    }
    
    // Referenced the VP9 code in Chrome that performs a similar function
    // https://source.chromium.org/chromium/chromium/src/+/main:media/gpu/mac/vt_config_util.mm;drc=977dc02c431b4979e34c7792bc3d646f649dacb4;l=155
    extensions[(__bridge NSString*)kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms] =
    @{
        @"av1C" : [self getAv1CodecConfigurationBox:frameData],
    };
    extensions[@"BitsPerComponent"] = @(bitstreamCtx->bit_depth);
    
#undef SET_EXTENSION
#undef SET_CFSTR_EXTENSION
    
    // AV1 doesn't have a special format description function like H.264 and HEVC have, so we just use the generic one
    CMVideoFormatDescriptionRef formatDesc = NULL;
    OSStatus status = CMVideoFormatDescriptionCreate(kCFAllocatorDefault, kCMVideoCodecType_AV1,
                                                     bitstreamCtx->frame_width, bitstreamCtx->frame_height,
                                                     (__bridge CFDictionaryRef)extensions,
                                                     &formatDesc);
    if (status != noErr) {
        Log(LOG_E, @"Failed to create AV1 format description: %d", (int)status);
        formatDesc = NULL;
    }
    
    ff_cbs_fragment_free(&cbsFrag);
    ff_cbs_close(&cbsCtx);
    return formatDesc;
}

// This function must free data for bufferType == BUFFER_TYPE_PICDATA
- (int)submitDecodeBuffer:(unsigned char *)data length:(int)length bufferType:(int)bufferType decodeUnit:(PDECODE_UNIT)du
{
    OSStatus status;
    
    // Construct a new format description object each time we receive an IDR frame
    if (du->frameType == FRAME_TYPE_IDR) {
        if (bufferType != BUFFER_TYPE_PICDATA) {
            if (bufferType == BUFFER_TYPE_VPS || bufferType == BUFFER_TYPE_SPS || bufferType == BUFFER_TYPE_PPS) {
                // Add new parameter set into the parameter set array
                int startLen = data[2] == 0x01 ? 3 : 4;
                [parameterSetBuffers addObject:[NSData dataWithBytes:&data[startLen] length:length - startLen]];
            }
            
            // Data is NOT to be freed here. It's a direct usage of the caller's buffer.
            
            // No frame data to submit for these NALUs
            return DR_OK;
        }
        
        // Create the new format description when we get the first picture data buffer of an IDR frame.
        // This is the only way we know that there is no more CSD for this frame.
        //
        // NB: This logic depends on the fact that we submit all picture data in one buffer!
        
        // Free the old format description
        if (formatDesc != NULL) {
            CFRelease(formatDesc);
            formatDesc = NULL;
        }
        
        if (videoFormat & VIDEO_FORMAT_MASK_H264) {
            // Construct parameter set arrays for the format description
            size_t parameterSetCount = [parameterSetBuffers count];
            const uint8_t* parameterSetPointers[parameterSetCount];
            size_t parameterSetSizes[parameterSetCount];
            for (int i = 0; i < parameterSetCount; i++) {
                NSData* parameterSet = parameterSetBuffers[i];
                parameterSetPointers[i] = parameterSet.bytes;
                parameterSetSizes[i] = parameterSet.length;
            }
            
            Log(LOG_I, @"Constructing new H264 format description");
            status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                         parameterSetCount,
                                                                         parameterSetPointers,
                                                                         parameterSetSizes,
                                                                         NAL_LENGTH_PREFIX_SIZE,
                                                                         &formatDesc);
            if (status != noErr) {
                Log(LOG_E, @"Failed to create H264 format description: %d", (int)status);
                formatDesc = NULL;
            }
            
            // Free parameter set buffers after submission
            [parameterSetBuffers removeAllObjects];
        }
        else if (videoFormat & VIDEO_FORMAT_MASK_H265) {
            // Construct parameter set arrays for the format description
            size_t parameterSetCount = [parameterSetBuffers count];
            const uint8_t* parameterSetPointers[parameterSetCount];
            size_t parameterSetSizes[parameterSetCount];
            for (int i = 0; i < parameterSetCount; i++) {
                NSData* parameterSet = parameterSetBuffers[i];
                parameterSetPointers[i] = parameterSet.bytes;
                parameterSetSizes[i] = parameterSet.length;
            }
            
            Log(LOG_I, @"Constructing new HEVC format description");
            
            NSMutableDictionary* videoFormatParams = [[NSMutableDictionary alloc] init];
            
            if (contentLightLevelInfo) {
                [videoFormatParams setObject:contentLightLevelInfo forKey:(__bridge NSString*)kCMFormatDescriptionExtension_ContentLightLevelInfo];
            }
            
            if (masteringDisplayColorVolume) {
                [videoFormatParams setObject:masteringDisplayColorVolume forKey:(__bridge NSString*)kCMFormatDescriptionExtension_MasteringDisplayColorVolume];
            }
            
            status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault,
                                                                         parameterSetCount,
                                                                         parameterSetPointers,
                                                                         parameterSetSizes,
                                                                         NAL_LENGTH_PREFIX_SIZE,
                                                                         (__bridge CFDictionaryRef)videoFormatParams,
                                                                         &formatDesc);
            
            if (status != noErr) {
                Log(LOG_E, @"Failed to create HEVC format description: %d", (int)status);
                formatDesc = NULL;
            }
            
            // Free parameter set buffers after submission
            [parameterSetBuffers removeAllObjects];
        }
        else if (videoFormat & VIDEO_FORMAT_MASK_AV1) {
            NSData* fullFrameData = [NSData dataWithBytesNoCopy:data length:length freeWhenDone:NO];
            
            Log(LOG_I, @"Constructing new AV1 format description");
            formatDesc = [self createAV1FormatDescriptionForIDRFrame:fullFrameData];
        }
        else {
            // Unsupported codec!
            abort();
        }

        if (_useVideoSuperResolution && ![self setupVideoSuperResolutionDecoder]) {
            Log(LOG_W, @"VideoSuperResolution setup failed. Falling back to default display pipeline.");
        }
    }
    
    if (formatDesc == NULL) {
        // Can't decode if we haven't gotten our parameter sets yet
        free(data);
        return DR_NEED_IDR;
    }
    
    // Check for previous decoder errors before doing anything
    if (displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
        Log(LOG_E, @"Display layer rendering failed: %@", displayLayer.error);
        
        // Recreate the display layer. We are already on the main thread,
        // so this is safe to do right here.
        [self reinitializeDisplayLayer];
        
        // Request an IDR frame to initialize the new decoder
        free(data);
        return DR_NEED_IDR;
    }
    
    // Now we're decoding actual frame data here
    CMBlockBufferRef frameBlockBuffer;
    CMBlockBufferRef dataBlockBuffer;
    
    status = CMBlockBufferCreateWithMemoryBlock(NULL, data, length, kCFAllocatorDefault, NULL, 0, length, 0, &dataBlockBuffer);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferCreateWithMemoryBlock failed: %d", (int)status);
        free(data);
        return DR_NEED_IDR;
    }
    
    // From now on, CMBlockBuffer owns the data pointer and will free it when it's dereferenced
    
    status = CMBlockBufferCreateEmpty(NULL, 0, 0, &frameBlockBuffer);
    if (status != noErr) {
        Log(LOG_E, @"CMBlockBufferCreateEmpty failed: %d", (int)status);
        CFRelease(dataBlockBuffer);
        return DR_NEED_IDR;
    }
    
    // H.264 and HEVC formats require NAL prefix fixups from Annex B to length-delimited
    if (videoFormat & (VIDEO_FORMAT_MASK_H264 | VIDEO_FORMAT_MASK_H265)) {
        int lastOffset = -1;
        for (int i = 0; i < length - NALU_START_PREFIX_SIZE; i++) {
            // Search for a NALU
            if (data[i] == 0 && data[i+1] == 0 && data[i+2] == 1) {
                // It's the start of a new NALU
                if (lastOffset != -1) {
                    // We've seen a start before this so enqueue that NALU
                    [self updateAnnexBBufferForRange:frameBlockBuffer dataBlock:dataBlockBuffer offset:lastOffset length:i - lastOffset];
                }
                
                lastOffset = i;
            }
        }
        
        if (lastOffset != -1) {
            // Enqueue the remaining data
            [self updateAnnexBBufferForRange:frameBlockBuffer dataBlock:dataBlockBuffer offset:lastOffset length:length - lastOffset];
        }
    }
    else {
        // For formats that require no length-changing fixups, just append a reference to the raw data block
        status = CMBlockBufferAppendBufferReference(frameBlockBuffer, dataBlockBuffer, 0, length, 0);
        if (status != noErr) {
            Log(LOG_E, @"CMBlockBufferAppendBufferReference failed: %d", (int)status);
            return DR_NEED_IDR;
        }
    }
        
    CMSampleBufferRef sampleBuffer;
    
    CMSampleTimingInfo sampleTiming = {kCMTimeInvalid, CMTimeMake(du->presentationTimeUs, 1000000), kCMTimeInvalid};
    
    status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                  frameBlockBuffer,
                                  formatDesc, 1, 1,
                                  &sampleTiming, 0, NULL,
                                  &sampleBuffer);
    if (status != noErr) {
        Log(LOG_E, @"CMSampleBufferCreate failed: %d", (int)status);
        CFRelease(dataBlockBuffer);
        CFRelease(frameBlockBuffer);
        return DR_NEED_IDR;
    }

    if (!_useVideoSuperResolution || ![self enqueueVideoSuperResolutionSampleBuffer:sampleBuffer decodeUnit:du]) {
        // Enqueue the next frame on the existing path if VideoSuperResolution is disabled
        // or if the optional YUV-to-RGB path couldn't process this frame.
        [self->displayLayer enqueueSampleBuffer:sampleBuffer];
        
        if (du->frameType == FRAME_TYPE_IDR) {
            // Ensure the layer is visible now
            self->displayLayer.hidden = NO;
            
            // Tell our parent VC to hide the progress indicator
            [self->_callbacks videoContentShown];
        }
    }
    
    // Dereference the buffers
    CFRelease(dataBlockBuffer);
    CFRelease(frameBlockBuffer);
    CFRelease(sampleBuffer);
    
    return DR_OK;
}

- (void)setHdrMode:(BOOL)enabled {
    SS_HDR_METADATA hdrMetadata;
    
    if (_useVideoSuperResolution && _videoSuperResolutionHdrEnabled != enabled) {
        _videoSuperResolutionHdrEnabled = enabled;
        [_videoSuperResolution setHdrEnabled:enabled];
        
        if (displayLayer != nil && videoWidth > 0 && videoHeight > 0) {
            _videoSuperResolutionTargetSize = [self videoSuperResolutionTargetSize];
            [_videoSuperResolution configureWithInputSize:CGSizeMake(videoWidth, videoHeight)
                                               outputSize:_videoSuperResolutionTargetSize];
        }
        
        [self invalidateVideoSuperResolutionDecoder];
    }
    
    BOOL hasMetadata = enabled && LiGetHdrMetadata(&hdrMetadata);
    BOOL metadataChanged = NO;
    
    if (hasMetadata && hdrMetadata.displayPrimaries[0].x != 0 && hdrMetadata.maxDisplayLuminance != 0) {
        // This data is all in big-endian
        struct {
          vector_ushort2 primaries[3];
          vector_ushort2 white_point;
          uint32_t luminance_max;
          uint32_t luminance_min;
        } __attribute__((packed, aligned(4))) mdcv;

        // mdcv is in GBR order while SS_HDR_METADATA is in RGB order
        mdcv.primaries[0].x = __builtin_bswap16(hdrMetadata.displayPrimaries[1].x);
        mdcv.primaries[0].y = __builtin_bswap16(hdrMetadata.displayPrimaries[1].y);
        mdcv.primaries[1].x = __builtin_bswap16(hdrMetadata.displayPrimaries[2].x);
        mdcv.primaries[1].y = __builtin_bswap16(hdrMetadata.displayPrimaries[2].y);
        mdcv.primaries[2].x = __builtin_bswap16(hdrMetadata.displayPrimaries[0].x);
        mdcv.primaries[2].y = __builtin_bswap16(hdrMetadata.displayPrimaries[0].y);

        mdcv.white_point.x = __builtin_bswap16(hdrMetadata.whitePoint.x);
        mdcv.white_point.y = __builtin_bswap16(hdrMetadata.whitePoint.y);

        // These luminance values are in 10000ths of a nit
        mdcv.luminance_max = __builtin_bswap32((uint32_t)hdrMetadata.maxDisplayLuminance * 10000);
        mdcv.luminance_min = __builtin_bswap32(hdrMetadata.minDisplayLuminance);

        NSData* newMdcv = [NSData dataWithBytes:&mdcv length:sizeof(mdcv)];
        if (masteringDisplayColorVolume == nil || ![newMdcv isEqualToData:masteringDisplayColorVolume]) {
            masteringDisplayColorVolume = newMdcv;
            metadataChanged = YES;
        }
    }
    else if (masteringDisplayColorVolume != nil) {
        masteringDisplayColorVolume = nil;
        metadataChanged = YES;
    }
    
    if (hasMetadata && hdrMetadata.maxContentLightLevel != 0 && hdrMetadata.maxFrameAverageLightLevel != 0) {
        // This data is all in big-endian
        struct {
            uint16_t max_content_light_level;
            uint16_t max_frame_average_light_level;
        } __attribute__((packed, aligned(2))) cll;

        cll.max_content_light_level = __builtin_bswap16(hdrMetadata.maxContentLightLevel);
        cll.max_frame_average_light_level = __builtin_bswap16(hdrMetadata.maxFrameAverageLightLevel);

        NSData* newCll = [NSData dataWithBytes:&cll length:sizeof(cll)];
        if (contentLightLevelInfo == nil || ![newCll isEqualToData:contentLightLevelInfo]) {
            contentLightLevelInfo = newCll;
            metadataChanged = YES;
        }
    }
    else if (contentLightLevelInfo != nil) {
        contentLightLevelInfo = nil;
        metadataChanged = YES;
    }
    
    // If the metadata changed, request an IDR frame to re-create the CMVideoFormatDescription
    if (metadataChanged) {
        LiRequestIdrFrame();
    }
}

@end
