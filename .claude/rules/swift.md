---
paths:
  - "BanhApp/**"
  - "BanhAppTests/**"
  - "BanhAppUITests/**"
---
- App SwiftUI đa nền tảng (iOS + macOS); tránh API chỉ có trên một nền tảng nếu không bọc `#if os(...)`.
- Unit test dùng XCTest trong `BanhAppTests`, UI test trong `BanhAppUITests`.
