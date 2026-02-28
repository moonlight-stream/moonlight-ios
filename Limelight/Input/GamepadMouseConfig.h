//
//  GamepadMouseConfig.h
//  Moonlight
//
//  平台差异化参数配置（iOS vs tvOS）
//

#ifndef GamepadMouseConfig_h
#define GamepadMouseConfig_h

#import <Foundation/Foundation.h>

typedef struct {
    NSTimeInterval pollInterval;  // 鼠标移动采样间隔
    float sensitivity;            // 灵敏度乘数
    float deadzone;               // 摇杆死区
    float scrollSpeed;            // 滚轮速度
} GamepadMouseConfig;

static inline GamepadMouseConfig GamepadMouseConfigDefault(void) {
#if TARGET_OS_TV
    return (GamepadMouseConfig){
        .pollInterval = 1.0 / 240.0,
        .sensitivity = 4.0f,
        .deadzone = 0.1f,
        .scrollSpeed = 2.0f,
    };
#else
    return (GamepadMouseConfig){
        .pollInterval = 1.0 / 120.0,
        .sensitivity = 3.0f,
        .deadzone = 0.1f,
        .scrollSpeed = 1.5f,
    };
#endif
}

#endif /* GamepadMouseConfig_h */
