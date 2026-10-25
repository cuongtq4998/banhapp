# ADR-0012: Glass and blur fallback, and use of a blur library

| Field    | Value |
| -------- | ----- |
| ADR      | 0012 |
| Status   | Accepted |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | UI TQ-8; design-system.md DS-Q2, `material.fallback`; ADR-0005 |

## Context

With minimum iOS 17 and Android API 26 (proposed in ADR-0005), real glass or blur is only available on iOS 26 and newer and Android 12 (API 31) and newer. The design system defines a fallback for the other devices. The question is whether a paid or third-party blur library may be used on Android below the native blur level.

## Decision Drivers

- Cost zero; few dependencies in a public repository.
- Contrast of 4.5:1 for text (design system).
- Performance on low-end devices.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Native only: `glassEffect` on iOS 26+, `Material` on iOS 17 to 25; `Modifier.blur`/`RenderEffect` on Android 12+, opaque tonal surface below | No dependency; stable | Android 8 to 11 devices look flatter |
| B. Add the open-source Haze library (Apache 2.0) for backdrop blur on Android 12+ | Blurs content behind bars while scrolling; maintained | A dependency; its API is still moving (2.0 alpha); low-API behaviour unverified |
| C. A paid blur library or software blur (RenderScript, deprecated) for Android 8 to 11 | Blur on old devices | Cost, deprecated technology, slow on low-end phones |

## Decision

Option A. Paid blur libraries are not allowed. On Android API 26 to 30 the app uses `color.surface.solid` at 94% (`material.fallback`), which also guarantees contrast. On API 31 and newer the background blobs use the native `Modifier.blur` (it blurs the element itself), and cards use a translucent tonal surface over them. Backdrop blur of scrolling content behind a bar is not required by the UI specification; if wanted later, the free Haze library may be adopted on API 31 and newer through a new ADR. On iOS, fallback is `Material` (ultra thin) over `color.surface.solid`; Reduce Transparency and Increase Contrast switch to the fallback on both platforms.

## Consequences

- Positive: no cost, no extra dependency.
- Negative: older Android devices see opaque cards (about 30% of devices, ADR-0005); visual QA must cover both renderings.
- Follow-up: probe-qa runs screenshots in both modes; contrast measured on built screens.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Haze is Apache 2.0, targets Android and other Compose platforms; release 1.6.0 added a RenderScript path for older Android; 2.0 is in alpha | https://chrisbanes.github.io/haze/ and https://newreleases.io/project/github/chrisbanes/haze/release/1.6.0 | 2026-10-25 | Medium (search summaries) |
| Real-time blur needs `RenderEffect` (API 31+); `Modifier.blur` is ineffective below | Android developer documentation; fetch attempt did not reach the entry | 2026-10-25 | Unverified |
| RenderScript is deprecated since Android 12 | Search summary only | 2026-10-25 | Low |
| Liquid Glass and Material fallback on iOS | https://developer.apple.com/documentation/swiftui/glasseffectcontainer.md | 2026-10-25 | High (glass); unverified (Material fallback) |

## Links

Related: ADR-0005, ADR-0007.
