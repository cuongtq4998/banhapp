# ADR-0005: Minimum iOS and Android versions

| Field    | Value |
| -------- | ----- |
| ADR      | 0005 |
| Version  | 1.1 |
| Status   | Accepted (owner decision: iOS 17 and Android 8.0 / API 26) [v1.1 | 2026-10-25] |
| Date     | 2026-10-25 |
| Decider  | Product owner (recommendation by atlas-architect) |
| Based on | PRD Q-T3; UI TQ-1; design-system DS-Q1 |

## Context

Liquid Glass needs iOS 26. Material 3 Expressive is a Compose Material3 feature. The Xcode project currently targets iOS 15. Raising a minimum later cuts users off; lowering it costs code. Customers are in Vietnam, where older and mid-range Android phones are common (unverified).

## Decision Drivers

- Reach: customers who cannot install cannot order.
- Cost of fallback rendering (design-system `material.fallback`).
- Platform APIs needed: iOS observation and navigation; Android `java.time`, Compose.
- Store rules: new uploads to App Store Connect must use the Xcode 26 SDK from 2026-04-28, but the deployment target may stay lower.

## Options Considered

iOS:

| Option | Pros | Cons |
| ------ | ---- | ---- |
| iOS 15 (current) | Widest reach | No `NavigationStack`, no `@Observable`; more legacy code; larger test matrix; simulators 15.x unusable on the host |
| iOS 16 | `NavigationStack` | No `@Observable`; modest gain |
| iOS 17 | `@Observable`, modern SwiftUI, small fallback surface; released 2023 | Excludes devices that stopped at iOS 16 or lower (iPhone 8/X and earlier; share unverified) |
| iOS 26 only | No fallback; pure Liquid Glass | Excludes devices that cannot or did not update; adoption figure only from a vendor survey (79% by June 2026, unverified) |

Android:

| Option | Pros | Cons |
| ------ | ---- | ---- |
| API 23 (Android 6) | Widest | Needs core library desugaring for `java.time`; very few users; larger test matrix |
| API 26 (Android 8.0) | `java.time` built in; Compose supported; reaches almost all active devices (unverified exact share) | About 30% of devices (below Android 12) get the opaque fallback instead of blur |
| API 31 (Android 12) | Native `RenderEffect` blur on every supported device; no fallback code for blur | About 30% of active devices excluded (Google figure for December 2025: Android 12 and newer about 69%, medium confidence) |

## Decision (accepted: iOS 17.0 and Android API 26) [v1.1 | 2026-10-25]

iOS 17.0 deployment target, iPhone only, built with the Xcode 26 SDK or newer; Liquid Glass on iOS 26 and newer guarded by `#available(iOS 26, *)`, `material.fallback` on iOS 17 to 25. Android `minSdk` 26, `targetSdk` the current Play requirement; real blur on API 31 and newer, `color.surface.solid` fallback on API 26 to 30 (ADR-0012). Reason: the customer app has no feature that needs newer OS versions, and a missed order costs the shop more than an opaque card.

## Consequences

- Positive: one code path per platform with a small, testable fallback.
- Negative: the existing project settings change (iOS 15 to 17, macOS/tvOS/visionOS targets removed, `TARGETED_DEVICE_FAMILY` set to iPhone). `CLAUDE.md` and `.claude/rules/swift.md` still describe a multiplatform iOS 15 app; the orchestrator updates them after the decision.
- Follow-up: re-evaluate yearly with real device statistics from the stores (not available before launch).

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Apps uploaded to App Store Connect must use Xcode 26 and the 26 SDKs from 2026-04-28 | https://www.developer.apple.com/news/upcoming-requirements/ | 2026-10-25 | Medium (search summary) |
| iOS 26 on 79% of active iPhones in June 2026 | https://rentamac.io/es/estadisticas-de-desarrollo-de-aplicaciones-para-ios/ (vendor survey) | 2026-10-25 | Low (unverified) |
| Android 12 (API 31) 11.4% of devices; cumulative about 69.3% (data of 2025-12-01) | https://heise.de/-11162154 | 2026-10-25 | Medium |
| Compose Material3 1.4.0 is the stable release; 1.5.0 in beta | https://developer.android.com/jetpack/androidx/releases/compose-material3 | 2026-10-25 | High |
| `@Observable` requires iOS 17; `NavigationStack` requires iOS 16; `Modifier.blur` effective on API 31 and newer; `java.time` available from API 26 | Platform documentation, not fetched | 2026-10-25 | Unverified |
| Vietnam device mix | Not researched | 2026-10-25 | Unverified |

## Links

Related: ADR-0006, ADR-0007, ADR-0012.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | Proposed. |
| 1.1 | 2026-10-25 | Accepted by the owner. Fallbacks fixed: iOS 17 to 25 material blur; Android below 12 opaque cards. |
