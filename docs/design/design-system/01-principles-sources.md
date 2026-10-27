# Design System, part 1: Principles and sources (section 1)

[v1.3 | 2026-10-27] Part of the split design system; index: [design-system.md](../design-system.md). Content unchanged from v1.2; section numbers are the original ones.

## 1. Principles

1. Native feel first. iOS follows Liquid Glass; Android follows Material 3 Expressive. One component name, two native renderings.
2. Glass and blur are used for navigation and action layers (bars, cards over the background), not for long text blocks. Text sits on surfaces that keep contrast of at least 4.5:1.
3. Every glass or blur surface has a documented fallback (older OS, Reduce Transparency, no blur support).
4. Whole-dong money. Amounts are shown as whole VND with a dot as thousands separator and the dong sign, for example `125.000 ₫` (sample number). No decimals.
5. Vietnamese text needs full diacritic support and extra line height; no component clips text at the largest text size.
6. Tokens carry semantic names. Feature documents use token names only.
7. [v1.2 | 2026-10-26] The owner's design board (`docs/design/reference/`) is the visual source of truth. The values in section 2 were extracted from its CSS; where the board and an earlier version of this document differed, the board won. "Board" below always means that folder. Sample names, numbers and bracketed placeholders on the board (for example `[Tên tiệm]`, `[Giá]`) are design placeholders; the apps show shop data as received.

### Sources and confidence

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| `GlassEffectContainer` merges several Liquid Glass shapes so they render together and can morph; used with `glassEffect(_:in:)`; available from iOS 26 | https://developer.apple.com/documentation/swiftui/glasseffectcontainer.md | 2026-10-25 | High (Apple documentation) |
| Variants `.regular`, `.clear`, `.interactive()`; button styles `.glass` and `.glassProminent`; `glassEffectID` morphing; glass should not sample other glass | Community guides, e.g. https://levelup.gitconnected.com/swiftui-liquid-glass-from-basic-to-a-little-advance-cdef4e4c5b90 and https://medium.com/@veersr9/ios-26-liquid-glass-in-swiftui-a-practical-reference-demo-app-liquidglassreference-69b8d46dc055 | 2026-10-25 | Medium (secondary; verify against Apple docs before build) |
| Liquid Glass automatically adapts to Reduce Transparency and Increase Contrast | Apple Human Interface Guidelines, Materials / Liquid Glass (not fetched) | 2026-10-25 | Unverified |
| Fallback for iOS before 26: SwiftUI `Material` backgrounds (`.ultraThinMaterial` or `.regularMaterial`) with a hairline stroke | Apple SwiftUI `Material` documentation (not fetched) | 2026-10-25 | Unverified |
| Material 3 Expressive components in Compose Material3: `LoadingIndicator`, `ButtonGroup`, `SplitButtonLayout`, `FloatingToolbar`, `FlexibleBottomAppBar`, `FloatingActionButtonMenu`, `MaterialExpressiveTheme`; seen in 1.4.0 alpha builds, some experimental | https://proandroiddev.com/material-3-expressive-design-a-new-era-9ea77959a262 and https://proandroiddev.com/material-3-expressive-design-a-new-era-part-2-6a93483c98b0 | 2026-10-25 | Medium (third-party articles; official Material 3 pages could not be read) |
| Material 3 Expressive stable status, spring-based motion scheme, shape morphing and the exact API names in the current Compose release | https://m3.material.io/blog/building-with-m3-expressive (page returned no readable content) | 2026-10-25 | Unverified |
| Real-time blur on Android needs `RenderEffect` (API 31+); older devices need a non-blur fallback | Android developer documentation (not fetched) | 2026-10-25 | Unverified |
| [v1.2 | 2026-10-26] Be Vietnam Pro and Roboto Flex are embedded in the board (SIL Open Font License 1.1, per `design/reference/README.md`); no licence fee | `design/reference/dat-banh-tet-ios-android.html` (licence comment at the top), README | 2026-10-26 | High for the board content; licence terms of the font files themselves not re-read from the font projects |
| [v1.2 | 2026-10-26] CSS pixel values of the board map one to one to pt (iOS, 390 x 844 frame) and dp (Android, 412 x 892 frame) | Board frame sizes | 2026-10-26 | High (the board was drawn at device point sizes) |
