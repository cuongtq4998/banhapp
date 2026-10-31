# Design System, part 6: Motion and haptics, accessibility, open questions, change log (sections 4 to 7)

[v1.3 | 2026-10-27] Part of the split design system; index: [design-system.md](../design-system.md). Content unchanged from v1.2; section numbers are the original ones. The UI document cites "design-system.md section 4" for the feedback table below.

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
- Text contrast at least 4.5:1; large text and icons at least 3:1. Text over glass uses `color.text.primary` on `color.surface.glass`; if contrast over a blob cannot be assured, the surface falls back to `color.surface.solid`. [v1.2 | 2026-10-26] Contrast to re-measure on built screens: white label on `color.primary.top` (#3F8A57, the lighter end of the button gradient, estimated about 4.4:1 and therefore the weak point; the label is 16 pt Semibold, so confirm 4.5:1 or darken the top stop), `color.text.secondary` on glass over the amber blob, `color.accentText` prices on glass.
- Every icon-only control has a text label for screen readers (the board gives the back button `aria-label` "Quay lại ...").
- Layout survives the largest text size: content scrolls vertically, rows wrap, nothing truncates a price, quantity, or message. [v1.2 | 2026-10-26] The board uses fixed heights for home action cards (132 / 140) and bar buttons; at large text they grow in height instead of clipping.
- State is never signalled by colour alone (unavailable dates also carry a text label for screen readers and a pattern, such as a diagonal strike, in the visual).
- Reduce Motion, Reduce Transparency and Increase Contrast (iOS) and remove-animations and high-contrast text (Android) are honoured through `motion.reduced` and `material.fallback`.

Component specifics are in the feature document.

## 6. Open Questions

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| DS-Q1 | Minimum iOS and Android versions (Liquid Glass needs iOS 26; Material 3 Expressive depends on the Compose Material3 release) | Decides how much of the fallback is built | No | technical | Closed [v1.1 | 2026-10-25] | iOS 17 and Android 8.0 (API 26), owner decision; ADR-0005 |
| DS-Q2 | Is paid or third-party UI tooling allowed (for example a blur library for Android below API 31)? | Fallback cost | No | technical | Closed [v1.1 | 2026-10-25] | No; native only (ADR-0012) |
| DS-Q3 | [v1.2 | 2026-10-26] Bundle Be Vietnam Pro (iOS) and Roboto Flex (Android) as app resources, as the board uses them? Variable or static font files, app size, text scaling with custom fonts, fallback to system fonts | Section 2.2; same question as TQ-11 in `place-order-ui.md`, for atlas-architect | No | technical | Open | Proposed: yes (free licence); fall back to the system font if a file is missing |

## 7. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version created with the place-order feature. |
| 1.1 | 2026-10-25 | Minimum OS versions fixed (iOS 17, Android 8.0) and fallbacks defined per level; `material.fallback` applicability; `ContactButton` Zalo uses generic icon plus word; stepper range 0 to 99; DS-Q1 and DS-Q2 closed. |
| 1.2 | 2026-10-26 | Reconciled with the owner's design board (`design/reference`): exact palette, background gradients and the three blobs per platform, glass values, typography (Be Vietnam Pro and Roboto Flex with the board's sizes, weights and tracking), radii, spacing margins and sizes, shadows, iconography, component styles; new tokens and components (`HeroActionCard`, `DayChipRow`, `InfoChip`, `color.accentText`, `color.primary.top`, `color.tertiaryContainer`, `color.destructive`, size and radius tokens); `TopBar` now a custom header; removed the earlier "ref" values and the system-font assumption; DS-Q3 opened; contrast watch-list. |
| 1.4 | 2026-10-29 | New component `PrivacyNoticeCard` (S-7 privacy notice, FR-20) built from existing tokens; `NoticeText` may carry a link. |
| 1.3 | 2026-10-27 | File split only (project 200-line rule): no change of meaning, see the index [design-system.md](../design-system.md). |
