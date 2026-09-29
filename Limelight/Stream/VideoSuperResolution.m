//
//  VideoSuperResolution.m
//  Moonlight
//

#import "VideoSuperResolution.h"
@import CoreImage;

#if __has_include(<MetalFX/MetalFX.h>)
@import MetalFX;
#define MOONLIGHT_HAS_METALFX 1
#else
#define MOONLIGHT_HAS_METALFX 0
#endif

@implementation VideoSuperResolution {
    // Metal objects reused for the whole session.
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    CIContext* _ciContext;

    // Explicit SDR and HDR destination spaces let us control YUV->RGB conversion.
    CGColorSpaceRef _rgbColorSpace;
    CGColorSpaceRef _hdrColorSpace;
    BOOL _isAvailable;
    BOOL _hdrEnabled;
    CVMetalTextureCacheRef _textureCache;

#if MOONLIGHT_HAS_METALFX
    // MetalFX resources created once for a given input/output size pair.
    id<MTLFXSpatialScaler> _spatialScaler;
    id<MTLTexture> _upscaledTexture;
#endif

    // Cached format/pool objects avoid per-frame allocations during streaming.
    CMVideoFormatDescriptionRef _outputFormatDescription;
    CVPixelBufferPoolRef _rgbPixelBufferPool;
    CVPixelBufferPoolRef _upscaledPixelBufferPool;
    size_t _inputWidth;
    size_t _inputHeight;
    size_t _outputWidth;
    size_t _outputHeight;
    BOOL _isConfigured;
}

// Copies one attachment while preserving the requested propagation mode.
- (void)copyAttachmentForKey:(CFStringRef)key
                  fromBuffer:(CVBufferRef)sourceBuffer
                    toBuffer:(CVBufferRef)destinationBuffer
                        mode:(CVAttachmentMode)mode
{
    if (key == NULL || sourceBuffer == NULL || destinationBuffer == NULL) {
        return;
    }

    CFTypeRef value = CVBufferGetAttachment(sourceBuffer, key, NULL);
    if (value != NULL) {
        CVBufferSetAttachment(destinationBuffer, key, value, mode);
    }
}

// Uses the source image buffer color space when available so the RGB conversion matches
// the decoder output as closely as possible. Fall back to explicit SDR/HDR spaces otherwise.
- (CGColorSpaceRef)destinationColorSpaceForImageBuffer:(CVImageBufferRef)imageBuffer
{
    CGColorSpaceRef sourceColorSpace = NULL;
    if (imageBuffer != NULL) {
        sourceColorSpace = (CGColorSpaceRef)CVBufferGetAttachment(imageBuffer,
                                                                  kCVImageBufferCGColorSpaceKey,
                                                                  NULL);
    }

    if (sourceColorSpace != NULL) {
        return sourceColorSpace;
    }

    if (_hdrEnabled && _hdrColorSpace != NULL) {
        return _hdrColorSpace;
    }

    return _rgbColorSpace;
}

// Propagates only the attachments that are still meaningful after converting the buffer to RGB.
- (void)copyAttachmentsFromBuffer:(CVBufferRef)sourceBuffer toBuffer:(CVBufferRef)destinationBuffer
{
    if (sourceBuffer == NULL || destinationBuffer == NULL) {
        return;
    }

    [self copyAttachmentForKey:kCVImageBufferCleanApertureKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];
    [self copyAttachmentForKey:kCVImageBufferPreferredCleanApertureKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];
    [self copyAttachmentForKey:kCVImageBufferPixelAspectRatioKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];
    [self copyAttachmentForKey:kCVImageBufferDisplayDimensionsKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];
    [self copyAttachmentForKey:kCVImageBufferMasteringDisplayColorVolumeKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];
    [self copyAttachmentForKey:kCVImageBufferContentLightLevelInfoKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];

    [self copyAttachmentForKey:kCVImageBufferColorPrimariesKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];
    [self copyAttachmentForKey:kCVImageBufferTransferFunctionKey
                    fromBuffer:sourceBuffer
                      toBuffer:destinationBuffer
                          mode:kCVAttachmentMode_ShouldPropagate];

    CGColorSpaceRef colorSpace = [self destinationColorSpaceForImageBuffer:(CVImageBufferRef)sourceBuffer];
    if (colorSpace != NULL) {
        CVBufferSetAttachment(destinationBuffer,
                              kCVImageBufferCGColorSpaceKey,
                              colorSpace,
                              kCVAttachmentMode_ShouldPropagate);
    }

    // The output buffer is RGB, so source YCbCr matrix/chroma metadata no longer applies.
    CVBufferRemoveAttachment(destinationBuffer, kCVImageBufferYCbCrMatrixKey);
    CVBufferRemoveAttachment(destinationBuffer, kCVImageBufferChromaLocationTopFieldKey);
    CVBufferRemoveAttachment(destinationBuffer, kCVImageBufferChromaLocationBottomFieldKey);
    CVBufferRemoveAttachment(destinationBuffer, kCVImageBufferChromaSubsamplingKey);
}

// Builds a fresh format description from the actual output pixel buffer so AVFoundation sees
// the real colorimetry of the converted frame instead of a stale generic description.
- (CMVideoFormatDescriptionRef)copyFormatDescriptionForImageBuffer:(CVImageBufferRef)imageBuffer CF_RETURNS_RETAINED
{
    if (imageBuffer == NULL) {
        return nil;
    }

    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                                   imageBuffer,
                                                                   &formatDescription);
    if (status != noErr) {
        NSLog(@"VideoSuperResolution: Failed to create per-frame format description: %d", (int)status);
        return nil;
    }

    return formatDescription;
}

// Preserves sample-buffer level attachments such as timing-agnostic HDR metadata.
- (void)copyAttachmentsFromSampleBuffer:(CMSampleBufferRef)sourceSampleBuffer
                         toSampleBuffer:(CMSampleBufferRef)destinationSampleBuffer
{
    if (sourceSampleBuffer == NULL || destinationSampleBuffer == NULL) {
        return;
    }

    CFDictionaryRef propagatedAttachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                          sourceSampleBuffer,
                                                                          kCMAttachmentMode_ShouldPropagate);
    if (propagatedAttachments != NULL) {
        CMSetAttachments(destinationSampleBuffer, propagatedAttachments, kCMAttachmentMode_ShouldPropagate);
        CFRelease(propagatedAttachments);
    }

    CFDictionaryRef nonPropagatedAttachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                             sourceSampleBuffer,
                                                                             kCMAttachmentMode_ShouldNotPropagate);
    if (nonPropagatedAttachments != NULL) {
        CMSetAttachments(destinationSampleBuffer, nonPropagatedAttachments, kCMAttachmentMode_ShouldNotPropagate);
        CFRelease(nonPropagatedAttachments);
    }
}

- (void)initializeResources
{
    if (_device != nil && _commandQueue != nil) {
        return;
    }

    // Metal is required for both the Core Image conversion path and the optional MetalFX scaler.
    _device = MTLCreateSystemDefaultDevice();
    if (_device == nil) {
        NSLog(@"VideoSuperResolution: Metal device unavailable");
        return;
    }

    _commandQueue = [_device newCommandQueue];
    if (_commandQueue == nil) {
        NSLog(@"VideoSuperResolution: Failed to create Metal command queue");
        _device = nil;
        return;
    }

    // Core Image performs the YUV->RGB conversion on the GPU to keep the CPU path light.
    _ciContext = [CIContext contextWithMTLDevice:_device];
    _rgbColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
    if (@available(iOS 12.3, tvOS 12.3, *)) {
        _hdrColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearITUR_2020);
    }

    // Older deployment targets don't expose the dedicated HDR linear 2020 space.
    // Fall back to a sane RGB space so the conversion path still compiles and runs.
    if (_hdrColorSpace == NULL) {
        _hdrColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
    }

    // The texture cache bridges CVPixelBuffer and Metal texture objects without manual copies.
    CVReturn cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, _device, NULL, &_textureCache);
    if (cacheStatus != kCVReturnSuccess) {
        NSLog(@"VideoSuperResolution: Failed to create Metal texture cache: %d", cacheStatus);
        _ciContext = nil;
        if (_rgbColorSpace != NULL) {
            CGColorSpaceRelease(_rgbColorSpace);
            _rgbColorSpace = NULL;
        }
        if (_hdrColorSpace != NULL) {
            CGColorSpaceRelease(_hdrColorSpace);
            _hdrColorSpace = NULL;
        }
        _commandQueue = nil;
        _device = nil;
        return;
    }

    // MetalFX may be unavailable either because the OS is too old or because the SDK target
    // being compiled (notably some simulator environments) does not expose the framework.
#if MOONLIGHT_HAS_METALFX
    if (@available(iOS 16.0, tvOS 16.0, *)) {
        _isAvailable = YES;
    }
    else {
        _isAvailable = NO;
        NSLog(@"VideoSuperResolution: MetalFX SpatialScaler unavailable on this OS version");
    }
#else
    _isAvailable = NO;
#endif
}

- (void)setHdrEnabled:(BOOL)enabled
{
    if (_hdrEnabled == enabled) {
        return;
    }

    _hdrEnabled = enabled;
    _isConfigured = NO;

    // HDR changes the pixel format, working color space, and MetalFX processing mode,
    // so every size-dependent cached object must be rebuilt.
    if (_outputFormatDescription != NULL) {
        CFRelease(_outputFormatDescription);
        _outputFormatDescription = NULL;
    }

    if (_rgbPixelBufferPool != NULL) {
        CFRelease(_rgbPixelBufferPool);
        _rgbPixelBufferPool = NULL;
    }

    if (_upscaledPixelBufferPool != NULL) {
        CFRelease(_upscaledPixelBufferPool);
        _upscaledPixelBufferPool = NULL;
    }

#if MOONLIGHT_HAS_METALFX
    _spatialScaler = nil;
    _upscaledTexture = nil;
#endif
}

// Creates a reusable pool for buffers that stay GPU-compatible all the way through the pipeline.
- (CVPixelBufferPoolRef)createPixelBufferPoolWithWidth:(size_t)width
                                                height:(size_t)height
                                           pixelFormat:(OSType)pixelFormat CF_RETURNS_RETAINED
{
    NSDictionary* pixelBufferAttributes = @{
        (id)kCVPixelBufferWidthKey : @(width),
        (id)kCVPixelBufferHeightKey : @(height),
        (id)kCVPixelBufferPixelFormatTypeKey : @(pixelFormat),
        (id)kCVPixelBufferMetalCompatibilityKey : @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    };
    NSDictionary* poolAttributes = @{
        (id)kCVPixelBufferPoolMinimumBufferCountKey : @3,
    };

    CVPixelBufferPoolRef pool = NULL;
    CVReturn status = CVPixelBufferPoolCreate(kCFAllocatorDefault,
                                              (__bridge CFDictionaryRef)poolAttributes,
                                              (__bridge CFDictionaryRef)pixelBufferAttributes,
                                              &pool);
    if (status != kCVReturnSuccess) {
        NSLog(@"VideoSuperResolution: Failed to create pixel buffer pool: %d", status);
        return nil;
    }

    return pool;
}

// Pulls a buffer from a pool instead of allocating a brand-new pixel buffer per frame.
- (CVPixelBufferRef)copyPixelBufferFromPool:(CVPixelBufferPoolRef)pixelBufferPool CF_RETURNS_RETAINED
{
    if (pixelBufferPool == NULL) {
        return nil;
    }

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer);
    if (status != kCVReturnSuccess) {
        NSLog(@"VideoSuperResolution: Failed to create pixel buffer from pool: %d", status);
        return nil;
    }

    return pixelBuffer;
}

// The intermediate RGB buffer always matches the decoder output size.
- (BOOL)prepareRGBPixelBufferPoolWithWidth:(size_t)width height:(size_t)height
{
    if (_rgbPixelBufferPool != NULL &&
        _inputWidth == width &&
        _inputHeight == height) {
        return YES;
    }

    if (_rgbPixelBufferPool != NULL) {
        CFRelease(_rgbPixelBufferPool);
        _rgbPixelBufferPool = NULL;
    }

    _rgbPixelBufferPool = [self createPixelBufferPoolWithWidth:width
                                                        height:height
                                                   pixelFormat:_hdrEnabled ? kCVPixelFormatType_64RGBAHalf : kCVPixelFormatType_32BGRA];
    return _rgbPixelBufferPool != NULL;
}

// Keeps a cached output format description for the common case where attachments do not force
// us to create a per-frame description later.
- (BOOL)prepareOutputFormatDescription
{
    if (_outputFormatDescription != NULL) {
        return YES;
    }

    CVPixelBufferRef outputPixelBuffer = nil;
    if (_upscaledPixelBufferPool != NULL) {
        outputPixelBuffer = [self copyPixelBufferFromPool:_upscaledPixelBufferPool];
    }
    else if (_rgbPixelBufferPool != NULL) {
        outputPixelBuffer = [self copyPixelBufferFromPool:_rgbPixelBufferPool];
    }

    if (outputPixelBuffer == NULL) {
        return NO;
    }

    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                                   outputPixelBuffer,
                                                                   &_outputFormatDescription);
    CFRelease(outputPixelBuffer);
    if (status != noErr) {
        NSLog(@"VideoSuperResolution: Failed to create output format description: %d", (int)status);
        _outputFormatDescription = NULL;
        return NO;
    }

    return YES;
}

// Creates the MetalFX scaler and the private texture that MetalFX requires as its render target.
- (BOOL)prepareUpscalerForInputWidth:(size_t)inputWidth
                         inputHeight:(size_t)inputHeight
                         outputWidth:(size_t)outputWidth
                        outputHeight:(size_t)outputHeight
{
#if !MOONLIGHT_HAS_METALFX
    return NO;
#else
    if (!_isAvailable) {
        return NO;
    }

    if (_spatialScaler != nil &&
        _inputWidth == inputWidth &&
        _inputHeight == inputHeight &&
        _outputWidth == outputWidth &&
        _outputHeight == outputHeight) {
        return YES;
    }

    if (@available(iOS 16.0, tvOS 16.0, *)) {
        MTLPixelFormat outputPixelFormat = _hdrEnabled ? MTLPixelFormatRGBA16Float : MTLPixelFormatBGRA8Unorm;

        // MetalFX writes into a private texture first, then we blit into a CVPixelBuffer-backed texture.
        MTLTextureDescriptor* outputDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:outputPixelFormat
                                                           width:outputWidth
                                                          height:outputHeight
                                                       mipmapped:NO];
        outputDescriptor.storageMode = MTLStorageModePrivate;

        MTLFXSpatialScalerDescriptor* descriptor = [[MTLFXSpatialScalerDescriptor alloc] init];
        descriptor.inputWidth = inputWidth;
        descriptor.inputHeight = inputHeight;
        descriptor.outputWidth = outputWidth;
        descriptor.outputHeight = outputHeight;
        descriptor.colorTextureFormat = outputPixelFormat;
        descriptor.outputTextureFormat = outputPixelFormat;
        descriptor.colorProcessingMode = _hdrEnabled ? MTLFXSpatialScalerColorProcessingModeHDR : MTLFXSpatialScalerColorProcessingModePerceptual;

        // The scaler describes the exact texture usage flags required by the driver.
        id<MTLFXSpatialScaler> spatialScaler = [descriptor newSpatialScalerWithDevice:_device];
        if (spatialScaler == nil) {
            NSLog(@"VideoSuperResolution: Failed to create MetalFX spatial scaler");
            return NO;
        }
        
        outputDescriptor.usage = spatialScaler.outputTextureUsage;

        id<MTLTexture> outputTexture = [_device newTextureWithDescriptor:outputDescriptor];
        if (outputTexture == nil) {
            NSLog(@"VideoSuperResolution: Failed to create private output texture");
            return NO;
        }

        spatialScaler.inputContentWidth = inputWidth;
        spatialScaler.inputContentHeight = inputHeight;
        spatialScaler.outputTexture = outputTexture;

        _spatialScaler = spatialScaler;
        _upscaledTexture = outputTexture;
        _inputWidth = inputWidth;
        _inputHeight = inputHeight;
        _outputWidth = outputWidth;
        _outputHeight = outputHeight;
        
        // The upscaled output is exposed through a CVPixelBuffer pool because AVSampleBufferDisplayLayer
        // still expects image buffers, not raw Metal textures.
        if (_upscaledPixelBufferPool != NULL) {
            CFRelease(_upscaledPixelBufferPool);
            _upscaledPixelBufferPool = NULL;
        }
        
        _upscaledPixelBufferPool = [self createPixelBufferPoolWithWidth:outputWidth
                                                                 height:outputHeight
                                                            pixelFormat:_hdrEnabled ? kCVPixelFormatType_64RGBAHalf : kCVPixelFormatType_32BGRA];
        if (_upscaledPixelBufferPool == NULL) {
            _spatialScaler = nil;
            return NO;
        }

        if (_outputFormatDescription != NULL) {
            CFRelease(_outputFormatDescription);
            _outputFormatDescription = NULL;
        }

        return YES;
    }

    return NO;
#endif
}

// This is the one-shot session configuration path called once the input stream size and the
// device display size are known.
- (BOOL)configureWithInputSize:(CGSize)inputSize outputSize:(CGSize)outputSize
{
    if (_device == nil || _ciContext == nil) {
        return NO;
    }

    size_t inputWidth = MAX(1, (size_t)llround(inputSize.width));
    size_t inputHeight = MAX(1, (size_t)llround(inputSize.height));
    size_t outputWidth = MAX(1, (size_t)llround(outputSize.width));
    size_t outputHeight = MAX(1, (size_t)llround(outputSize.height));

    if (_isConfigured &&
        _inputWidth == inputWidth &&
        _inputHeight == inputHeight &&
        _outputWidth == outputWidth &&
        _outputHeight == outputHeight) {
        return YES;
    }

    if (_outputFormatDescription != NULL) {
        CFRelease(_outputFormatDescription);
        _outputFormatDescription = NULL;
    }

    if (![self prepareRGBPixelBufferPoolWithWidth:inputWidth height:inputHeight]) {
        _isConfigured = NO;
        return NO;
    }

    // Only enable MetalFX when the target is strictly larger than the decoded frame.
    if (outputWidth > inputWidth && outputHeight > inputHeight) {
        if (![self prepareUpscalerForInputWidth:inputWidth
                                    inputHeight:inputHeight
                                    outputWidth:outputWidth
                                   outputHeight:outputHeight]) {
            _isConfigured = NO;
            return NO;
        }
    }
    else {
        if (_upscaledPixelBufferPool != NULL) {
            CFRelease(_upscaledPixelBufferPool);
            _upscaledPixelBufferPool = NULL;
        }
#if MOONLIGHT_HAS_METALFX
        _spatialScaler = nil;
        _upscaledTexture = nil;
#endif
        _inputWidth = inputWidth;
        _inputHeight = inputHeight;
        _outputWidth = inputWidth;
        _outputHeight = inputHeight;
    }

    // Keep a cached format description around for fast sample buffer creation.
    if (![self prepareOutputFormatDescription]) {
        _isConfigured = NO;
        return NO;
    }

    _isConfigured = YES;
    return YES;
}

// Runs the MetalFX stage and copies the private result into a pixel-buffer-backed texture.
- (CVPixelBufferRef)copyUpscaledPixelBufferFromRGBPixelBuffer:(CVPixelBufferRef)rgbPixelBuffer
                                                   CF_RETURNS_RETAINED
{
#if !MOONLIGHT_HAS_METALFX
    return nil;
#else
    if (!_isConfigured || _spatialScaler == nil || _upscaledPixelBufferPool == NULL) {
        return nil;
    }

    size_t inputWidth = _inputWidth;
    size_t inputHeight = _inputHeight;
    size_t outputWidth = _outputWidth;
    size_t outputHeight = _outputHeight;

    // Wrap the RGB intermediate buffer as a Metal texture without copying it.
    CVMetalTextureRef inputTextureRef = NULL;
    CVReturn cvStatus = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                  _textureCache,
                                                                  rgbPixelBuffer,
                                                                  NULL,
                                                                  _hdrEnabled ? MTLPixelFormatRGBA16Float : MTLPixelFormatBGRA8Unorm,
                                                                  inputWidth,
                                                                  inputHeight,
                                                                  0,
                                                                  &inputTextureRef);
    if (cvStatus != kCVReturnSuccess || inputTextureRef == NULL) {
        NSLog(@"VideoSuperResolution: Failed to create input texture from RGB pixel buffer: %d", cvStatus);
        return nil;
    }

    id<MTLTexture> inputTexture = CVMetalTextureGetTexture(inputTextureRef);
    if (inputTexture == nil) {
        CFRelease(inputTextureRef);
        return nil;
    }

    CVPixelBufferRef outputPixelBuffer = [self copyPixelBufferFromPool:_upscaledPixelBufferPool];
    if (outputPixelBuffer == NULL) {
        CFRelease(inputTextureRef);
        return nil;
    }

    // Wrap the displayable output pixel buffer as a Metal texture for the final blit.
    CVMetalTextureRef outputTextureRef = NULL;
    cvStatus = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         _textureCache,
                                                         outputPixelBuffer,
                                                         NULL,
                                                         _hdrEnabled ? MTLPixelFormatRGBA16Float : MTLPixelFormatBGRA8Unorm,
                                                         outputWidth,
                                                         outputHeight,
                                                         0,
                                                         &outputTextureRef);
    if (cvStatus != kCVReturnSuccess || outputTextureRef == NULL) {
        NSLog(@"VideoSuperResolution: Failed to create output texture from pixel buffer: %d", cvStatus);
        CFRelease(inputTextureRef);
        CFRelease(outputPixelBuffer);
        return nil;
    }

    id<MTLTexture> outputTexture = CVMetalTextureGetTexture(outputTextureRef);
    if (outputTexture == nil) {
        CFRelease(inputTextureRef);
        CFRelease(outputTextureRef);
        CFRelease(outputPixelBuffer);
        return nil;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    if (commandBuffer == nil) {
        CFRelease(inputTextureRef);
        CFRelease(outputTextureRef);
        CFRelease(outputPixelBuffer);
        return nil;
    }

    // MetalFX writes into the private texture declared during configuration.
    _spatialScaler.colorTexture = inputTexture;
    [_spatialScaler encodeToCommandBuffer:commandBuffer];

    // Copy the private result into the CVPixelBuffer-backed texture consumed by AVFoundation.
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    [blitEncoder copyFromTexture:_upscaledTexture
                     sourceSlice:0
                     sourceLevel:0
                    sourceOrigin:MTLOriginMake(0, 0, 0)
                      sourceSize:MTLSizeMake(outputWidth, outputHeight, 1)
                       toTexture:outputTexture
                destinationSlice:0
                destinationLevel:0
               destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blitEncoder endEncoding];

    [commandBuffer commit];
    
    // Do not wait here: blocking the CPU on every frame causes severe input latency.
    // [commandBuffer waitUntilCompleted];

    CFRelease(inputTextureRef);
    CFRelease(outputTextureRef);

    return outputPixelBuffer;
#endif
}

// Converts the decoder output into an RGB sample buffer that preserves the source timing and
// the HDR/color metadata expected by AVSampleBufferDisplayLayer.
- (CMSampleBufferRef)copyRGBSampleBufferFromImageBuffer:(CVImageBufferRef)imageBuffer
                                       sourceSampleBuffer:(CMSampleBufferRef)sourceSampleBuffer
                                  presentationTimeStamp:(CMTime)presentationTimeStamp
                                               duration:(CMTime)duration
{
    if (_device == nil || _ciContext == nil || imageBuffer == nil || !_isConfigured) {
        return nil;
    }

    CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)imageBuffer;
    if (CVPixelBufferGetWidth(pixelBuffer) != _inputWidth ||
        CVPixelBufferGetHeight(pixelBuffer) != _inputHeight) {
        return nil;
    }

    CVPixelBufferRef rgbPixelBuffer = [self copyPixelBufferFromPool:_rgbPixelBufferPool];
    if (rgbPixelBuffer == NULL) {
        return nil;
    }

    CIImage* image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CGColorSpaceRef destinationColorSpace = [self destinationColorSpaceForImageBuffer:imageBuffer];

    // Core Image performs the actual YUV->RGB conversion here.
    [_ciContext render:image
       toCVPixelBuffer:rgbPixelBuffer
                bounds:CGRectMake(0, 0, _inputWidth, _inputHeight)
            colorSpace:destinationColorSpace];
    [self copyAttachmentsFromBuffer:imageBuffer toBuffer:rgbPixelBuffer];

    CVPixelBufferRef outputPixelBuffer = rgbPixelBuffer;
#if MOONLIGHT_HAS_METALFX
    if (_spatialScaler != nil) {
        // Upscaling is optional; the conversion-only path still uses the same metadata flow.
        CVPixelBufferRef upscaledPixelBuffer = [self copyUpscaledPixelBufferFromRGBPixelBuffer:rgbPixelBuffer];
        if (upscaledPixelBuffer != NULL) {
            [self copyAttachmentsFromBuffer:rgbPixelBuffer toBuffer:upscaledPixelBuffer];
            outputPixelBuffer = upscaledPixelBuffer;
            CFRelease(rgbPixelBuffer);
        }
    }
#endif

    if (_outputFormatDescription == NULL) {
        CFRelease(outputPixelBuffer);
        return nil;
    }

    CMSampleTimingInfo sampleTiming = {
        .duration = duration,
        .presentationTimeStamp = presentationTimeStamp,
        .decodeTimeStamp = kCMTimeInvalid,
    };

    // Prefer a per-frame format description so the latest HDR attachments are visible to the display layer.
    CMVideoFormatDescriptionRef outputFormatDescription = [self copyFormatDescriptionForImageBuffer:outputPixelBuffer];
    if (outputFormatDescription == NULL) {
        outputFormatDescription = _outputFormatDescription;
        if (outputFormatDescription != NULL) {
            CFRetain(outputFormatDescription);
        }
    }

    if (outputFormatDescription == NULL) {
        CFRelease(outputPixelBuffer);
        return nil;
    }

    CMSampleBufferRef rgbSampleBuffer = NULL;
    OSStatus status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                                               outputPixelBuffer,
                                                               outputFormatDescription,
                                                               &sampleTiming,
                                                               &rgbSampleBuffer);
    CFRelease(outputFormatDescription);
    CFRelease(outputPixelBuffer);

    if (status != noErr) {
        NSLog(@"VideoSuperResolution: Failed to create RGB sample buffer: %d", (int)status);
        return nil;
    }

    // Preserve sample-level attachments after the new CMSampleBuffer has been created.
    [self copyAttachmentsFromSampleBuffer:sourceSampleBuffer toSampleBuffer:rgbSampleBuffer];

    return rgbSampleBuffer;
}

- (void)dealloc
{
    if (_outputFormatDescription != NULL) {
        CFRelease(_outputFormatDescription);
    }

    if (_rgbPixelBufferPool != NULL) {
        CFRelease(_rgbPixelBufferPool);
    }
    
    if (_upscaledPixelBufferPool != NULL) {
        CFRelease(_upscaledPixelBufferPool);
    }

    if (_textureCache != NULL) {
        CFRelease(_textureCache);
    }
    
    if (_rgbColorSpace != NULL) {
        CGColorSpaceRelease(_rgbColorSpace);
    }
    
    if (_hdrColorSpace != NULL) {
        CGColorSpaceRelease(_hdrColorSpace);
    }
}

@end
