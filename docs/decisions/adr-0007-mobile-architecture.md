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

Android toolchain (as built in slice 0; versions read from the official pages on 2026-10-26) [v1.1 | 2026-10-26]:

| Item | Value | Note |
| ---- | ----- | ---- |
| Android Gradle Plugin | 9.4.0 (latest stable) | Requires Gradle 9.6.0, JDK 17, build tools 36.0.0; supports up to API 37 |
| Kotlin | 2.4.21 (latest stable, released 2026-10-08) | AGP 9 has built-in Kotlin: the `org.jetbrains.kotlin.android` plugin is not applied. The Compose compiler plugin `org.jetbrains.kotlin.plugin.compose` is still applied, at the same version as Kotlin |
| Compose BOM | 2026.09.00 (newest listed) | Maps to Material3 1.4.0 and Compose UI 1.12.1, consistent with the 1.4.x rule above |
| Gradle | 9.6.0 | The minimum and default for AGP 9.4; Gradle 9.8.x also exists and may be tried later, not required |
| JDK | 17 (Temurin in CI) | `sourceCompatibility` and `targetCompatibility` 17 |
| compileSdk, targetSdk, minSdk | 36, 36, 26 | Play target-level requirement still to be checked at submission (deployment.md section 4) |
| CI | `ubuntu-latest` (Ubuntu 24.04), `android-actions/setup-android@v3` with `platforms;android-36 build-tools;36.0.0`, `gradle/actions/setup-gradle@v4` | `.github/workflows/android.yml` |

Not verified: whether the Compose compiler plugin at 2.4.21 composes cleanly with AGP's built-in Kotlin (the project has never been built; first CI run decides). The Gradle wrapper is still to be generated and committed.

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
| AGP 9.4.0 is latest stable; needs Gradle 9.6.0, JDK 17, build tools 36.0.0 | https://developer.android.com/build/releases/gradle-plugin | 2026-10-26 | High |
| AGP 9 includes Kotlin support; `kotlin-android` plugin no longer needed | https://developer.android.com/build/migrate-to-built-in-kotlin | 2026-10-26 | High (the page says nothing about the Compose compiler plugin) |
| Kotlin 2.4.21 latest stable, 2026-10-08 | https://kotlinlang.org/docs/releases.html | 2026-10-26 | High |
| BOM 2026.09.00 maps to Material3 1.4.0, UI 1.12.1 | https://developer.android.com/develop/ui/compose/bom/bom-mapping | 2026-10-26 | Medium (rows matched by position; last 7 KB of the page not read) |
| `ubuntu-latest` is Ubuntu 24.04; `macos-latest` is macOS 26 arm64 | https://github.com/actions/runner-images | 2026-10-26 | High |
| `@Observable`, `NavigationStack`, DataStore, Navigation Compose behaviour | Platform documentation, not fetched | 2026-10-25 | Unverified |

## Links

Related: ADR-0005, ADR-0006, ADR-0011, ADR-0012, ADR-0016 (application identifiers).

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-26 | Android toolchain versions and CI runner recorded with sources (clarification only; decision unchanged). |
