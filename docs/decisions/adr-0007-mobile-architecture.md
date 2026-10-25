# ADR-0007: Mobile app architecture

| Field    | Value |
| -------- | ----- |
| ADR      | 0007 |
| Status   | Accepted |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | place-order-ui.md v1.0; ADR-0005, ADR-0006 |

## Context

Two small native apps with nine screens, one four-step flow with state kept across steps (FR-15), one write call. They need clear folders for developers and few dependencies for a public repository.

## Decision Drivers

- Simplicity and testability (flow rules are pure logic).
- Few third-party dependencies (supply chain, upgrade effort).
- Same structure on both platforms so one description fits both.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. MVVM per feature; one `OrderFlow` state holder shared by steps; repository layer for network and cache; manual dependency wiring | Small, testable, no framework | Manual wiring grows if the app grows |
| B. MVVM plus a DI framework (Hilt, Koin, swift-dependencies) | Standard wiring | Extra dependency for nine screens |
| C. Redux-style unidirectional store (TCA on iOS, MVI on Android) | Strong state discipline | Learning cost; heavy for this size; TCA is a large dependency |

## Decision

Option A on both platforms.

iOS (`ios/BanhApp/`): SwiftUI, `@Observable` view models (iOS 17), `NavigationStack`, async/await with `URLSession`, `Codable`. Folders: `App`, `Features/{Home,Products,Order,Confirmation}`, `Core/{Network,Storage,Design}`. No third-party packages.

Android (`android/app/`): Kotlin, Jetpack Compose with Material3 (stable 1.4.x, Expressive APIs behind `@OptIn(ExperimentalMaterial3ExpressiveApi::class)`; move to 1.5.x when it is stable; no beta in releases), ViewModel with `StateFlow`, Navigation Compose, OkHttp with kotlinx.serialization, DataStore for the draft, manual wiring through one `AppContainer`. Packages: `ui/{home,products,order,confirmation}`, `data`, `design`.

Rules common to both:

- One `OrderFlow` state object owns the draft (items, date, slot, name, phone, address, district, note, idempotency key) and survives step navigation (FR-15).
- Validation rules (phone, lengths, minimum quantity, date window) live in one `OrderRules` unit per platform, tested against `contracts/fixtures`.
- The server is the authority; the client never sends computed values except `expected_total_vnd` (price acknowledgement, ADR-0010).
- Strings come from resource files keyed by the UI document keys (`Localizable.xcstrings`, `res/values/strings.xml` with Vietnamese as the only language).
- Dates are shown in Vietnam time using the server date (`server_date`), not the device clock.
- Network timeout for order submission: 10 s (PRD performance); loads: 15 s.

## Consequences

- Positive: minimal dependencies; each folder has one purpose.
- Negative: no ready-made DI; revisit with a new ADR if features grow.
- Follow-up: dev guide (forge-dev) lists commands per platform.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Compose Material3 1.4.0 stable; ButtonGroup and FloatingToolbar expressive APIs became non-experimental in 1.5.0-alpha22 | https://developer.android.com/jetpack/androidx/releases/compose-material3 | 2026-10-25 | Medium (page partly read) |
| Which Expressive components are available in 1.4.0 without opt-in | Release notes not fully read | 2026-10-25 | Unverified |
| `@Observable`, `NavigationStack`, DataStore, Navigation Compose behaviour | Platform documentation, not fetched | 2026-10-25 | Unverified |

## Links

Related: ADR-0005, ADR-0006, ADR-0011, ADR-0012.
