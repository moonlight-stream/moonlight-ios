#import <Foundation/Foundation.h>

@interface NativeAppleMic : NSObject

// Call start and stop from the connection's serialized lifecycle.
- (BOOL)startWhileAllowed:(BOOL (^)(void))allowed onFailure:(void (^)(void))failure;
- (void)stop;

@end
