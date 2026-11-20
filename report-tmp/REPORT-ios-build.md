# ios-build run 44751164886 @ 3b7155b4935208cde898920758cd53216884e224

## Simulator 构建日志尾部
```
Command line invocation:
    /Applications/Xcode_16.4.app/Contents/Developer/usr/bin/xcodebuild build -project TypeFree.xcodeproj -scheme TypeFree -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" CODE_SIGNING_ALLOWED=NO

Build settings from command line:
    CODE_SIGNING_ALLOWED = NO

Resolve Package Graph


Resolved source packages:
  TypeFreeCore: /Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore

2026-11-20 14:19:07.209 xcodebuild[1206:6296] Writing error result bundle to /var/folders/9d/l02zfgrs7c16twd3wbpdmhkc0000gn/T/ResultBundle_2026-20-11_14-19-0007.xcresult
xcodebuild: error: Unable to find a device matching the provided destination specifier:
		{ platform:iOS Simulator, OS:latest, name:iPhone 16 }

	The requested device could not be found because no available devices matched the request.

	Available destinations for the "TypeFree" scheme:
		{ platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], id:b08e3fc725051a51163dd2542cfcb491488d85d2, name:My Mac }
		{ platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
		{ platform:iOS Simulator, id:dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder, name:Any iOS Simulator Device }
```

## 真机构建日志尾部
```
(无日志)
```
