#Moonlight iOS

#### Now available on the [App Store](https://itunes.apple.com/us/app/moonlight-game-streaming/id1000551566?mt=8)

[Moonlight](http://moonlight-stream.com) is an open source implementation of NVIDIA's GameStream, as used by the NVIDIA Shield, but built for iOS. Moonlight iOS allows you to stream your full collection of Steam games from
your powerful desktop computer to your iOS Device.

There are also versions for [Android](https://github.com/moonlight-stream/moonlight-android) and [PC](https://github.com/moonlight-stream/moonlight-pc).

#### Building
Initialize all submodules
```bash
git submodule update --init --recursive
```
Then build with Xcode


##### Apple TV Note:
Moonlight iOS now also works on tvOS with some limitations.  Support is unofficial since the API's required are private, this means that currently Moonlight iOS cannot be deployed to the tvOS AppStore.  It can, however, be sideloaded provided you have your own Apple Developer account.
In order to build, first follow the steps above to initialize submodules.
Then open the appropriate header as root (with editor of choice)
```bash
$> sudo nano /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVSampleBufferDisplayLayer.h
```

Change lines `41` and `46` and comment out `__TVOS_PROHIBITED` (Note: line numbers may change with different SDK versions.  Ensure to add the trailing semicolon on line `41`)
```objc
} NS_AVAILABLE(10_10, 8_0); // __TVOS_PROHIBITED;

AVF_EXPORT NSString *const AVSampleBufferDisplayLayerFailedToDecodeNotification NS_AVAILABLE(10_10, 8_0) __TVOS_PROHIBITED; // decode failed, see NSError in notification payload
AVF_EXPORT NSString *const AVSampleBufferDisplayLayerFailedToDecodeNotificationErrorKey NS_AVAILABLE(10_10, 8_0) __TVOS_PROHIBITED; // NSError

NS_CLASS_AVAILABLE(10_8, 8_0) // __TVOS_PROHIBITED
```

After this is done, Open `Moonlight.xcodeproj`, set target to `Moonlight tvOS`, and build.
A USB-C cable is required to sideload to Apple TV.




##### Questions?
Check out our [wiki](https://github.com/moonlight-stream/moonlight-docs/wiki).
