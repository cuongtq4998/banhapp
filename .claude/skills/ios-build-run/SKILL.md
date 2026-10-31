---
name: ios-build-run
description: Dùng khi cần build app SwiftUI BanhApp, chạy trên simulator iOS hoặc chạy test Xcode, kể cả qua ddagent
---

# Build và chạy BanhApp

Điều kiện: Xcode đầy đủ, `xcode-select -p` phải trỏ vào `Xcode-27.1.0-Release.Candidate.app` (không phải CommandLineTools).

- Liệt kê scheme: `xcodebuild -list -project BanhApp.xcodeproj`
- Build: `xcodebuild -project BanhApp.xcodeproj -scheme BanhApp build`
- Test: `xcodebuild -project BanhApp.xcodeproj -scheme BanhApp test`
- Một test: thêm `-only-testing:BanhAppTests/BanhAppTests/<tên>`

Build mọi nền tảng: lặp `-destination` qua `generic/platform=iOS Simulator`, `iOS`, `macOS`, `tvOS Simulator`, `visionOS Simulator` (thêm `CODE_SIGNING_ALLOWED=NO`). Target tối thiểu: iOS/tvOS 15.0, macOS 12.0, visionOS 1.0, nên API mới phải bọc `#available`. ddagent chỉ chạy simulator iOS/iPadOS; runtime iOS 15.5 và 16.0 không dùng được trên máy này.

Chạy trên nhiều simulator bằng ddagent (tận dụng cache DerivedData):
```
ddagent run --target "iPhone 16"
```
Build lần đầu là `cold`; cùng code chạy lại là `cache-hit`. Dùng `prewarm` để build + boot + install mà không launch.

Nếu `xcodebuild` báo cần Xcode: đặt `DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer` trước lệnh (không cần sudo), hoặc nhờ người dùng chạy `! sudo xcode-select -s /Applications/Xcode-27.1.0-Release.Candidate.app`.
