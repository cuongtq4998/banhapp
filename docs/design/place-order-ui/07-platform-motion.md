# Place Order UI, part 7: Platform notes, motion and haptics (sections 6, 7)

[v1.4 | 2026-10-27] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Content unchanged from v1.3; section numbers are the original ones.

## 6. Platform Notes

Identical on both platforms unless listed. Technology below follows section 2. [v1.1 | 2026-10-25] Minimum versions (owner decision): iOS 17 and Android 8.0 (API 26). Three rendering levels exist per platform; layout, sizes, copy and behaviour are identical in all of them.

| Level | iOS | Android |
| ----- | --- | ------- |
| Full | iOS 26 and later: Liquid Glass on cards, bars and glass button styles | Android 12 (API 31) and later: Material 3 Expressive with translucent tonal cards (`color.surface.glass`) over natively blurred background blobs |
| Fallback | iOS 17 to 25: material blur. Cards and bars use `material.fallback` (system ultra-thin material over `color.surface.solid`) with the hairline `color.surface.stroke`; buttons use plain filled (`PrimaryButton`) and tonal (`SecondaryButton`) styles in place of glass styles; no morphing between glass shapes | Android 8.0 to 11 (API 26 to 30): opaque cards. Cards and bar use `color.surface.solid` at 94% with no blur, `elevation` shadows kept; background blobs stay as flat soft gradients (no blur) |
| Accessibility override | Reduce Transparency or Increase Contrast on any version: `material.fallback` with higher-contrast stroke | Reduced transparency or high-contrast text on any version: `color.surface.solid` |

The fallback levels keep text contrast of at least 4.5:1 by design (opaque or near-opaque surfaces). No paid or third-party blur library is used (ADR-0012).

| Topic | iOS | Android |
| ----- | --- | ------- |
| UI technology | SwiftUI; Liquid Glass (`glassEffect` inside `GlassEffectContainer`, glass button styles) on iOS 26 and later | Jetpack Compose; Material 3 Expressive (`MaterialExpressiveTheme`, floating toolbar or flexible bottom app bar, `LoadingIndicator`; [v1.3 | 2026-10-26] `ButtonGroup` only where it can be styled to the board's capsule stepper) |
| Fallback | [v1.1 | 2026-10-25] iOS 17 to 25: `material.fallback` with the same layout; also used when Reduce Transparency is on | Android 8.0 to 11, or reduced transparency: `material.fallback` (opaque card surface) |
| Logo container | Glass rounded square (corner 40 pt large, 24 pt small) [v1.3 | 2026-10-26] | Organic blob shape, `color.primaryContainer` fill [v1.3 | 2026-10-26] |
| Top bar | [v1.3 | 2026-10-26] Custom header: round glass back button, large title below, native navigation bar hidden; swipe-back kept | Round glass back button, large title below; system back and predictive back kept |
| Bottom action bar | Floating glass bar, 16 pt sides, 28 pt from the bottom edge | Floating glass bar, 12 dp sides, 20 dp from the bottom edge; stays above gesture or button navigation |
| Primary button fill | [v1.3 | 2026-10-26] Vertical gradient `color.primary.top` to `color.primary` with shadow | Flat `color.primary` |
| Home action cards | [v1.3 | 2026-10-26] 132 pt high, symmetric corners 36 pt | 140 dp high, asymmetric corners (44 dp with one 16 dp corner) |
| Typeface | [v1.3 | 2026-10-26] Be Vietnam Pro (pending TQ-11), system font fallback | Roboto Flex (pending TQ-11), Roboto fallback |
| District picker | Sheet with list | Modal bottom sheet with list |
| Steppers | Glass capsule with two transparent buttons [v1.3 | 2026-10-26] | Capsule with a transparent minus and a filled plus button around the value [v1.3 | 2026-10-26] |
| Loading | Skeleton, system spinner for the confirm button | Skeleton, `LoadingIndicator` for the confirm button |
| Zalo and phone | [v1.1 | 2026-10-25] Zalo opens as a web link `https://zalo.me/<number>` and phone as `tel:` (ADR-0015); the Zalo button uses a generic chat icon (system symbol) plus the word "Zalo" | Same; generic chat icon (Material Symbol) plus the word "Zalo" |
| Haptics and motion | See section 7 | See section 7 |

## 7. Motion & Haptics

Standard tokens and feedback table: `design-system.md` section 4. Specific to this feature:

| Moment | Motion | Haptic |
| ------ | ------ | ------ |
| S-1 to S-2 | Logo cross-fades into the home layout, `motion.duration.long` | None |
| Between order steps | Native push and pop; `StepIndicator` segment fills with `motion.spring.standard` | None |
| Quantity change (S-5) | Value cross-fade; totals count with a short cross-fade | Selection (iOS), segment tick (Android) |
| Date or slot chosen (S-6) | Fill change | Selection / context click |
| Validation failure (S-7) and blocked confirm (S-8) | Message appears; field shakes once | Error notification / reject |
| Confirm tapped (S-8) | Button morphs to its loading form | Light impact / context click |
| Order received (S-9) | `StatusMark` plays with `motion.spring.bouncy`, order code fades in after 150 ms | Success notification / confirm |
| Reduce Motion / remove animations | All of the above become 150 ms cross-fades; blobs stay still | Haptics unchanged |
