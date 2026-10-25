# Design System

| Field        | Value                                                                 |
| ------------ | --------------------------------------------------------------------- |
| Version      | 1.1                                                                   |
| Last updated | 2026-10-25                                                            |
| Status       | Draft                                                                 |
| Owner        | canvas-ui                                                             |
| Based on     | product/place-order.md v1.2 (first consumer); no earlier design system |
| Related      | design/place-order-ui.md                                              |

## 1. Principles

1. Native feel first. iOS follows Liquid Glass; Android follows Material 3 Expressive. One component name, two native renderings.
2. Glass and blur are used for navigation and action layers (bars, cards over the background), not for long text blocks. Text sits on surfaces that keep contrast of at least 4.5:1.
3. Every glass or blur surface has a documented fallback (older OS, Reduce Transparency, no blur support).
4. Whole-dong money. Amounts are shown as whole VND with a dot as thousands separator and the dong sign, for example `125.000 ₫` (sample number). No decimals.
5. Vietnamese text needs full diacritic support and extra line height; no component clips text at the largest text size.
6. Tokens carry semantic names. Feature documents use token names only.

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

## 2. Tokens

Values marked "ref" come from the visual direction (mockups, reference only). Contrast ratios were estimated by hand and shall be re-measured on built screens.

### 2.1 Color

Backgrounds are a vertical soft gradient with blurred colour blobs behind content.

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `color.primary` | Primary button, key accents | #2F6B3F (ref) | #1D6B3A (ref) |
| `color.onPrimary` | Text and icons on primary | #FFFFFF | #FFFFFF |
| `color.primaryContainer` | Tonal fill: selected chip, selected date, contact buttons | #D6EBD9 | #C4EFCB |
| `color.onPrimaryContainer` | Text on primary container | #123A20 | #00210C |
| `color.background.top` | Gradient start | #F3F7EA | #F3F7EA |
| `color.background.bottom` | Gradient end (cream) | #F8F1DD | #F8F1DD |
| `color.blob.green` | Blurred background blob | #8FC79A at 45% | #8FC79A at 45% |
| `color.blob.cream` | Blurred background blob | #F1D9A0 at 45% | #F1D9A0 at 45% |
| `color.surface.glass` | Card and bar surface (translucent) | White at 55% over blur (Liquid Glass) | White at 70% over blur |
| `color.surface.solid` | Fallback when glass or blur is unavailable | #FBF8EE | #FBF8EE |
| `color.surface.stroke` | Hairline edge of glass surfaces | White at 60%, 1 pt | White at 60%, 1 dp |
| `color.text.primary` | Body and titles | #1B2A1F (about 14:1 on cream) | #1B2A1F |
| `color.text.secondary` | Descriptions, hints | #4A5A4E (about 6.5:1 on cream) | #4A5A4E |
| `color.text.disabled` | Disabled labels | #7B857D | #7B857D |
| `color.error` | Error text and field outline | #B3261E (about 5.8:1 on cream) | #B3261E |
| `color.errorContainer` | Error banner fill | #FBE4E1 | #F9DEDC |
| `color.warningContainer` | Info or rule hint banner fill | #FFF1CC | #FFF1CC |
| `color.disabledFill` | Disabled button and unavailable date fill | Text at 12% | Text at 12% |
| `color.focus` | Keyboard and switch-access focus ring | #1A56DB | #1A56DB |

### 2.2 Typography

iOS uses the system font (SF Pro) with Dynamic Type text styles. Android uses the system sans-serif (Roboto family) with the Material 3 type scale and `sp` units. Both must render Vietnamese diacritics; no custom font is required.

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `type.display` | Logo screen, order code | Title 1, 28 pt, Bold | Headline Medium, 28 sp, Bold (emphasized) |
| `type.title.large` | Screen titles, shop name | Large Title, 34 pt, Bold | Headline Large, 32 sp, Bold (emphasized) |
| `type.title.medium` | Card titles, section titles | Title 3, 20 pt, Semibold | Title Large, 22 sp, Medium |
| `type.body` | Descriptions, fields | Body, 17 pt, Regular | Body Large, 16 sp, Regular |
| `type.body.strong` | Prices, totals | Body, 17 pt, Semibold | Body Large, 16 sp, Medium |
| `type.label` | Buttons, chips | Headline, 17 pt, Semibold | Label Large, 14 sp, Medium |
| `type.caption` | Hints, counters, step indicator | Footnote, 13 pt, Regular | Body Small, 12 sp, Regular |

All text scales with the system setting (iOS up to the largest accessibility size; Android up to 200% font scale).

### 2.3 Spacing

4-point grid.

| Token | iOS | Android |
| ----- | --- | ------- |
| `space.xs` | 4 pt | 4 dp |
| `space.sm` | 8 pt | 8 dp |
| `space.md` | 12 pt | 12 dp |
| `space.lg` | 16 pt | 16 dp |
| `space.xl` | 24 pt | 24 dp |
| `space.xxl` | 32 pt | 32 dp |
| `space.screenMargin` | 20 pt | 20 dp |
| `size.touchTarget` | 44 pt minimum | 48 dp minimum |
| `size.buttonHeight` | 54 pt | 56 dp |
| `size.thumb` | 72 pt square | 72 dp square |

### 2.4 Radius

| Token | iOS | Android |
| ----- | --- | ------- |
| `radius.card` | 28 pt (ref), continuous corner | 28 dp (ref, extra large) |
| `radius.pill` | Capsule | Full (stadium) |
| `radius.field` | 16 pt continuous | 16 dp |
| `radius.image` | 20 pt continuous | 20 dp |
| `radius.logo` | Rounded square 30 pt | Organic blob (expressive shape, "cookie" or wavy polygon) |

### 2.5 Elevation and material

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `elevation.card` | Glass cards | Liquid Glass regular, soft shadow 0/8 blur 24 at 10% | Tonal surface level 1 plus blurred translucent fill where supported, shadow 2 dp |
| `elevation.bar` | Floating bottom action bar | Liquid Glass regular, floats 8 pt above the safe area | Floating toolbar, tonal level 3, floats 8 dp above navigation bar inset |
| `elevation.sheet` | Sheets, pickers | System sheet material | Modal bottom sheet, tonal level 1 |
| `material.fallback` | Glass fallback [v1.1 | 2026-10-25] (iOS 17 to 25; Android 8.0 to 11 and any version with reduced transparency) | `Material` (ultra thin) over `color.surface.solid`, hairline `color.surface.stroke` | `color.surface.solid` at 94% without blur (opaque card) |

### 2.6 Motion

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `motion.duration.short` | Taps, toggles | 150 ms | 150 ms |
| `motion.duration.medium` | Appear, error message | 250 ms | 250 ms |
| `motion.duration.long` | Screen transitions, launch exit | 400 ms | 400 ms |
| `motion.spring.standard` | Default movement | Spring, response 0.4, damping 0.85 | Expressive spatial spring, medium stiffness, damping ratio about 0.8 (unverified) |
| `motion.spring.bouncy` | Confirmation emphasis | Spring, response 0.5, damping 0.65 | Expressive spatial spring, low stiffness, damping ratio about 0.6 (unverified) |
| `motion.reduced` | When Reduce Motion or "remove animations" is on | Cross-fade 150 ms, no blobs drift | Cross-fade 150 ms, no blobs drift |

## 3. Components

Platform mapping column gives the native building block (names are indicative; the developer confirms against the SDK at build time).

| Component | Purpose | Variants | States | iOS mapping | Android mapping |
| --------- | ------- | -------- | ------ | ----------- | --------------- |
| `AppBackground` | Gradient with blurred blobs behind every screen | One | Static; blobs still when `motion.reduced` | SwiftUI gradient plus blurred shapes | Compose gradient plus blurred shapes |
| `LogoMark` | Shop logo | Large (launch), Small (home) | Static | Rounded square (`radius.logo`) | Blob shape (`radius.logo`) |
| `TopBar` | Screen title and back | Large title, Inline title; back control | Default, scrolled (glass appears) | Navigation bar with Liquid Glass toolbar; large title | Large flexible top app bar (M3) |
| `GlassCard` | Container for grouped content | Static, Tappable | Default, Pressed, Disabled | `glassEffect` in a rounded rectangle (`radius.card`) inside `GlassEffectContainer`; fallback `material.fallback` | Surface with `radius.card`, tonal container, blur if available |
| `BottomActionBar` | Floating bar holding the screen's primary (and secondary) action | One or two buttons stacked | Default, Disabled action, Loading action | Floating Liquid Glass bar | Floating toolbar or flexible bottom app bar (M3 Expressive) |
| `PrimaryButton` | Main action | Full width | Default, Pressed, Disabled, Loading | Prominent glass button style, tinted `color.primary`, capsule | Filled button, stadium, `color.primary` |
| `SecondaryButton` | Alternative action | Full width | Default, Pressed, Disabled | Glass button style (non-prominent) | Tonal button (`color.primaryContainer`) |
| `ContactButton` | Zalo or phone shortcut | Zalo (generic chat icon plus the word "Zalo"; no brand mark, ADR-0015) [v1.1 | 2026-10-25], Phone (phone icon plus label) | Default, Pressed, Disabled | Glass capsule with label; `material.fallback` capsule on iOS 17 to 25 | Tonal button in a `ButtonGroup` |
| `QuantityStepper` limits | [v1.1 | 2026-10-25] Value from 0 to 99; plus disabled at 99 with no message | | | | |
| `ProductCard` | Product in list | List row with `size.thumb` image, name, description (two lines max), price | Default, Pressed, Loading (skeleton), Image failed | `GlassCard` tappable | `GlassCard` tappable, expressive shape on image |
| `QuantityStepper` | Choose quantity 0 and up | Minus, value, plus | Default, Min (minus disabled at 0), Pressed | Custom capsule with two buttons; value is a label | Button group with two icon buttons around a label |
| `StepIndicator` | "Step n of 4" | Text plus progress segments | Current, done | Segmented capsule | Segmented progress (linear) |
| `DateGrid` | Month calendar for date choice | Month header with previous and next; day cells | Day: Available, Selected, Unavailable (full or out of range), Today marker | Custom grid (the system graphical date picker cannot mark capacity-based dates unavailable: unverified, confirm) | Custom grid (same reason; Material date picker supports range validation only: unverified) |
| `SlotChip` | Delivery time slot | Single-select chip, full-width list | Default, Selected, Disabled | Capsule in a glass list | Filter chip or selectable list item, `color.primaryContainer` when selected |
| `TextField` | Single-line text | Text, Phone, Multiline (note) | Default, Focused, Filled, Error, Disabled | Rounded field on glass with label above | Outlined text field with supporting text |
| `PickerField` | Choose district | Opens list | Default, Selected, Error, Loading, Disabled | Field opening a sheet list (or menu) | Exposed dropdown or modal bottom sheet list |
| `SummaryRow` | Label and value on review | Text value, Money value, Multiline value, Total (emphasized) | Default | HStack in `GlassCard` | Row in `GlassCard` |
| `InlineMessage` | Message near a control or at the top of a section | Error, Info | Visible, hidden | Icon plus text on `color.errorContainer` or `color.warningContainer` | Same |
| `NoticeText` | Short privacy sentence | One | Default | `type.caption` text | `type.caption` text |
| `OrderCodeDisplay` | Large order code | One | Default | Selectable text, `type.display` | Selectable text, `type.display` |
| `StateView` | Full-area loading, empty or error | Loading (skeleton or spinner), Empty, Error with retry | Loading, Empty, Error | Skeleton placeholders; error uses icon, text, `SecondaryButton` | Expressive `LoadingIndicator`; same layout |
| `Toast` | Short non-blocking notice (cannot open Zalo or dialer) | One | Shown 4 s | Glass capsule at top | Snackbar above the bar |
| `StatusMark` | Success mark on confirmation | One | Animated, static | SF Symbol checkmark in circle with bounce effect | Animated vector check in blob shape |

Fallbacks for older systems:

- [v1.1 | 2026-10-25] Minimum versions (owner decision, ADR-0005): iOS 17 and Android 8.0 (API 26).
- iOS 17 to 25 (before Liquid Glass): `GlassCard` and `BottomActionBar` render with `material.fallback` (system material blur over `color.surface.solid`, hairline stroke); `PrimaryButton` is a filled capsule in `color.primary`, `SecondaryButton` and `ContactButton` are material capsules; no glass morphing between shapes. Layout and sizes stay identical. iOS 26 and later: Liquid Glass.
- Android 12 (API 31) and later: translucent tonal cards over natively blurred background blobs. Android 8.0 to 11 (API 26 to 30): opaque cards and bar with `color.surface.solid` at 94%, no blur, blobs as flat soft gradients, same layout. No paid or third-party blur library (ADR-0012).
- Reduce Transparency, Increase Contrast, remove animations or high-contrast text on any version: `material.fallback`.

## 4. Motion & Haptics

| Event | Motion | iOS haptic | Android haptic |
| ----- | ------ | ---------- | -------------- |
| Push or pop screen | Native navigation transition, `motion.duration.long`; Android uses shared-axis or predictive back | None | None |
| Bar action pressed | Scale to 0.97 with `motion.spring.standard` | Light impact | Context click (virtual key) |
| Quantity changed | Value cross-fade `motion.duration.short` | Selection | Segment tick |
| Date or slot selected | Fill change `motion.duration.short` | Selection | Context click |
| Blocked action or validation failure | Message appears with `motion.duration.medium`; field shakes 4 pt once (skipped under `motion.reduced`) | Notification error | Reject |
| Order confirmed | `StatusMark` plays with `motion.spring.bouncy` | Notification success | Confirm |
| Order not sent | Banner slides in | Notification error | Reject |

Haptic names are indicative of native feedback generators (UIKit feedback generators; Compose `HapticFeedbackType`); exact constants are unverified and are confirmed at build time.

## 5. Accessibility

Defaults from `docs/process/standards/02-ui.md`:

- Touch target at least `size.touchTarget` (44 pt iOS, 48 dp Android), including stepper buttons and calendar day cells.
- Text contrast at least 4.5:1; large text and icons at least 3:1. Text over glass uses `color.text.primary` on `color.surface.glass`; if contrast over a blob cannot be assured, the surface falls back to `color.surface.solid`.
- Every icon-only control has a text label for screen readers.
- Layout survives the largest text size: content scrolls vertically, rows wrap, nothing truncates a price, quantity, or message.
- State is never signalled by colour alone (unavailable dates also carry a text label for screen readers and a pattern, such as a diagonal strike, in the visual).
- Reduce Motion, Reduce Transparency and Increase Contrast (iOS) and remove-animations and high-contrast text (Android) are honoured through `motion.reduced` and `material.fallback`.

Component specifics are in the feature document.

## 6. Open Questions

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| DS-Q1 | Minimum iOS and Android versions (Liquid Glass needs iOS 26; Material 3 Expressive depends on the Compose Material3 release) | Decides how much of the fallback is built | No | technical | Closed [v1.1 | 2026-10-25] | iOS 17 and Android 8.0 (API 26), owner decision; ADR-0005 |
| DS-Q2 | Is paid or third-party UI tooling allowed (for example a blur library for Android below API 31)? | Fallback cost | No | technical | Closed [v1.1 | 2026-10-25] | No; native only (ADR-0012) |

## 7. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version created with the place-order feature. |
| 1.1 | 2026-10-25 | Minimum OS versions fixed (iOS 17, Android 8.0) and fallbacks defined per level; `material.fallback` applicability; `ContactButton` Zalo uses generic icon plus word; stepper range 0 to 99; DS-Q1 and DS-Q2 closed. |
