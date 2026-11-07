# Moonlight iOS/tvOS

[![CI](https://github.com/moonlight-stream/moonlight-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/moonlight-stream/moonlight-ios/actions/workflows/ci.yml)

[Moonlight for iOS/tvOS](https://moonlight-stream.org) is an open source client for [Sunshine](https://github.com/LizardByte/Sunshine) and NVIDIA GameStream. Moonlight for iOS/tvOS allows you to stream your full collection of games and apps from your powerful desktop computer to your iOS device or Apple TV.

Moonlight also has a [PC client](https://github.com/moonlight-stream/moonlight-qt) and [Android client](https://github.com/moonlight-stream/moonlight-android).

Check out [the Moonlight wiki](https://github.com/moonlight-stream/moonlight-docs/wiki) for more detailed project information, setup guide, or troubleshooting steps.

[![Moonlight for iOS and tvOS](https://moonlight-stream.org/images/App_Store_Badge_135x40.svg)](https://apps.apple.com/us/app/moonlight-game-streaming/id1000551566)

## Building
* Install Xcode from the [App Store page](https://apps.apple.com/us/app/xcode/id497799835)
* Run `git clone --recursive https://github.com/moonlight-stream/moonlight-ios.git`
  *  If you've already clone the repo without `--recursive`, run `git submodule update --init --recursive`
* Open Moonlight.xcodeproj in Xcode
* To run on a real device, you will need to locally modify the signing options:
    * Click on "Moonlight" at the top of the left sidebar
    * Click on the "Signing & Capabilities" tab
    * Under "Targets", select "Moonlight" (for iOS/iPadOS) or "Moonlight TV" (for tvOS)
    * In the "Team" dropdown, select your name. If your name doesn't appear, you may need to sign into Xcode with your Apple account.
    * Change the "Bundle Identifier" to something different. You can add your name or some random letters to make it unique.
    * Now you can select your Apple device in the top bar as a target and click the Play button to run.

## Native GameStream microphone

On iOS/iPadOS 17 or later and tvOS 17 or later, open an app tile's launch
options and choose **Launch [app] with Microphone** or **Resume [app] with
Microphone**. Grant recording permission when prompted. Apple TV requires
a supported Bluetooth or Continuity input that the OS makes available.

The choice applies to one stream. An on-screen label reports capture
status. Leaving the stream, interruption, inactivity or loss of the input
route stops forwarding. Start a new explicitly opted-in stream to resume
capture.

Use the [compatible Windows NVIDIA GameStream host setup](https://github.com/Bargs/native-gamestream-microphone-host)
and a trusted private IPv4 network or secured tunnel. The native legacy
CBC mode does not authenticate packets. The shared transport is reviewed
in [common-c PR #173](https://github.com/moonlight-stream/moonlight-common-c/pull/173).

Both arm64 device targets passed source and link checks with resource
phases omitted. Standard app packaging and on-device permission, route
and live host delivery need verification.
