# core-tests run 44750461250 @ 9f2e3b24034cd080a7f629dd4d7ebe3c01d42a23

## grep 摘要
```
17:/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
21:   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
25:/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
29:   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
33:/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
37:   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
41:/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
45:   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
49:/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
53:   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
56:error: fatalError
```

## 日志尾部 300 行
```
Building for debugging...
[0/7] /Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/.build/arm64-apple-macosx/debug/TypeFreeCorePackageTests.derived/runner.swift
[0/7] Write sources
[4/7] Write swift-version--79AA4F9932D1E87A.txt
[6/18] Emitting module TypeFreeCore
[7/23] Compiling TypeFreeCore ProviderModels.swift
[8/23] Compiling TypeFreeCore StylePreset.swift
[9/23] Compiling TypeFreeCore EndpointResolver.swift
[10/23] Compiling TypeFreeCore HTTPClient.swift
[11/23] Compiling TypeFreeCore MultipartBody.swift
[12/23] Compiling TypeFreeCore SSEParser.swift
[13/23] Compiling TypeFreeCore VoicePipeline.swift
[14/23] Compiling TypeFreeCore Redactor.swift
[15/23] Compiling TypeFreeCore STTEngines.swift
[16/23] Compiling TypeFreeCore ProviderVault.swift
[17/23] Compiling TypeFreeCore WavEncoder.swift
/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
45 |     public func jsonData() throws -> Data {
46 |         let encoder = JSONEncoder()
47 |         encoder.sortedKeys = true
   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
48 |         return try encoder.encode(self)
49 |     }
[18/23] Compiling TypeFreeCore HistoryStore.swift
/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
45 |     public func jsonData() throws -> Data {
46 |         let encoder = JSONEncoder()
47 |         encoder.sortedKeys = true
   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
48 |         return try encoder.encode(self)
49 |     }
[19/23] Compiling TypeFreeCore LLMEngines.swift
/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
45 |     public func jsonData() throws -> Data {
46 |         let encoder = JSONEncoder()
47 |         encoder.sortedKeys = true
   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
48 |         return try encoder.encode(self)
49 |     }
[20/23] Compiling TypeFreeCore PolishService.swift
/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
45 |     public func jsonData() throws -> Data {
46 |         let encoder = JSONEncoder()
47 |         encoder.sortedKeys = true
   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
48 |         return try encoder.encode(self)
49 |     }
[21/23] Compiling TypeFreeCore AppSettings.swift
/Users/runner/work/TypeFree-iOS/TypeFree-iOS/Packages/TypeFreeCore/Sources/TypeFreeCore/Models/AppSettings.swift:47:17: error: value of type 'JSONEncoder' has no member 'sortedKeys'
45 |     public func jsonData() throws -> Data {
46 |         let encoder = JSONEncoder()
47 |         encoder.sortedKeys = true
   |                 `- error: value of type 'JSONEncoder' has no member 'sortedKeys'
48 |         return try encoder.encode(self)
49 |     }
error: fatalError
```
