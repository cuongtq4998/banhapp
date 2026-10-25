# ADR-0006: Two native apps instead of one cross-platform codebase

| Field    | Value |
| -------- | ----- |
| ADR      | 0006 |
| Status   | Accepted |
| Date     | 2026-10-25 |
| Decider  | atlas-architect (owner stated the native look as a requirement in 00-request.md) |
| Based on | 00-request.md "Look and feel"; design-system.md principle 1 |

## Context

The owner wants Liquid Glass on iOS and Material 3 Expressive on Android. An Xcode SwiftUI project already exists. The customer app has nine screens and one network call that matters.

## Decision Drivers

- Faithful native components (glass effects, expressive components, predictive back, haptics).
- Effort: one developer team; nine simple screens.
- Long-term maintenance cost.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Native SwiftUI app and native Jetpack Compose app | Direct access to `glassEffect` and Material3 Expressive; best accessibility behaviour; no bridge | Two codebases; every change is made twice |
| B. Flutter | One codebase; custom rendering | Liquid Glass and Material3 Expressive are re-implemented, not native; accessibility and platform behaviour need extra care |
| C. React Native | One codebase; native widgets | Liquid Glass and Expressive need native modules or lag behind; JS runtime and build chain |
| D. Kotlin Multiplatform with native UI | Shared logic (validation, models, API client) | Extra build tooling for iOS; benefit small for nine screens |

## Decision

Option A. The owner's visual requirement is the deciding factor; the cross-platform options reproduce platform looks rather than use them. Duplication is limited by the contract: `contracts/fixtures` hold shared sample requests and responses, and `api.md` fixes validation rules so both clients implement the same ones. Option D can be revisited if logic grows (new ADR).

## Consequences

- Positive: native look and behaviour; no third-party UI framework to track.
- Negative: each business rule shown in the UI (minimum quantity, date window, phone format) is implemented twice; mitigated by shared fixtures and server authority.
- Follow-up: the same test cases (probe-qa) run on both platforms.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| `glassEffect` and `GlassEffectContainer` are SwiftUI APIs from iOS 26 | https://developer.apple.com/documentation/swiftui/glasseffectcontainer.md | 2026-10-25 | High |
| Material 3 Expressive APIs exist in Compose Material3 | https://developer.android.com/jetpack/androidx/releases/compose-material3 | 2026-10-25 | Medium |
| Flutter and React Native do not expose Liquid Glass natively | Not researched | 2026-10-25 | Unverified |

## Links

Related: ADR-0005, ADR-0007.
