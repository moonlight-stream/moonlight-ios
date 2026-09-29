//
//  VideoSuperResolution.h
//  Moonlight
//

#import <Foundation/Foundation.h>
@import CoreMedia;
@import CoreVideo;
@import Metal;

@interface VideoSuperResolution : NSObject

// Creates the Metal/Core Image state shared by the whole streaming session.
- (void)initializeResources;

// Rebuilds cached resources when the stream switches between SDR and HDR.
- (void)setHdrEnabled:(BOOL)enabled;

// Prepares all resources that only depend on the fixed input and output sizes for the session.
- (BOOL)configureWithInputSize:(CGSize)inputSize outputSize:(CGSize)outputSize;

// Converts the decoder output from YUV to RGB, optionally upscales it with MetalFX,
// and returns a new sample buffer ready for AVSampleBufferDisplayLayer.
- (CMSampleBufferRef _Nullable)copyRGBSampleBufferFromImageBuffer:(CVImageBufferRef _Nonnull)imageBuffer
                                       sourceSampleBuffer:(CMSampleBufferRef _Nullable)sourceSampleBuffer
                                  presentationTimeStamp:(CMTime)presentationTimeStamp
                                               duration:(CMTime)duration CF_RETURNS_RETAINED;

@end
