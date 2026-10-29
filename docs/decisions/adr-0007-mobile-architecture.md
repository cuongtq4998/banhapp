# ADR-0007: Mobile app architecture

| Field    | Value |
| -------- | ----- |
| ADR      | 0007 |
| Status   | Accepted. v1.5: iOS MVVM-C and Android MVI by owner decision 2026-10-27 [v1.5 | 2026-10-27] |
| Version  | 1.6 |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | place-order-ui.md v1.0; ADR-0005, ADR-0006; ADR-0018 v2.0; a research review of 2026-10-27 (summarised under Options) |

## Context

Two small native apps with nine screens, one four-step flow with state kept across steps (FR-15), one write call. They need clear folders for developers and few dependencies for a public repository.

## Decision Drivers

- Simplicity and testability (flow rules are pure logic).
- Few third-party dependencies (supply chain, upgrade effort).
- Same rules on both platforms (state kept across steps, pure validation, server authority). The patterns differ because each platform's native idiom is different [v1.5 | 2026-10-27].

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. MVVM per feature on both platforms; `NavigationStack` with a `Route` enum on iOS, no coordinator; manual wiring (v1.0 to v1.4) | Smallest; fewest types; the research review scored it highest for this size | Navigation is spread over views or one root view; no single owner of the path |
| B. MVVM plus a DI framework (Hilt, Koin, swift-dependencies) | Standard wiring | Extra dependency for nine screens |
| C. Redux-style store on both platforms (TCA on iOS) | Strong state discipline | Learning cost; TCA is a large dependency |
| D. iOS MVVM-C, Android MVI hand-written, manual DI (chosen by the owner, v1.5) | Navigation has one owner per flow on iOS; one predictable state-event model on Android; no new dependency | More types than A; the iOS coordinator can degrade into forwarding calls (conditions below) |

Honest record [v1.5 | 2026-10-27]: a research review scored a separate coordinator lower for an app of this size, because `NavigationStack` with a `Route` enum already does the job, and the same review preferred plain MVVM to MVI on Android. The owner chose option D anyway, for a navigation owner that is testable without views on iOS, and an explicit state, intent and effect model on Android. This is a deliberate decision against the review's score, not a hidden disagreement; the risks below belong to it.

## Decision

Option D (owner decision 2026-10-27, final) [v1.5 | 2026-10-27].

### iOS (`ios/BanhApp/`): MVVM-C

SwiftUI, `@Observable` view models (iOS 17), `NavigationStack`, async/await with `URLSession`, `Codable`. No third-party packages. Folders: `App`, `Features/{Home,Products,Order,Confirmation}`, `Core/{Network,Storage,Design}`, plus `Coordinators/` for coordinators and the `Route` enums.

| Layer | Owns | Must not |
| ----- | ---- | -------- |
| Coordinator | Navigation only: builds screens, pushes, presents, dismisses, holds the `NavigationPath` and the `Route` enum, owns child coordinators (the order flow has its own) | Hold business logic, call the network, format data |
| View model (`@Observable`) | Business logic and state of one screen; calls repositories | Know navigation or UIKit; import another feature |
| View | Layout and bindings only | Decide where to navigate; hold logic |

How a feature asks to navigate (closed gap): the feature declares a small intent enum (for example `ProductListIntent.openDetail(productID)`) and receives a closure `(Intent) -> Void` from the coordinator at construction. The coordinator maps intents to `Route` values. Features do not import each other, the coordinator type or `Route`. Tests feed a fake closure and assert the intent.

Conditions (the coordinator stays thin): no business logic in a coordinator; a coordinator method that only forwards a call to another object is removed in review; when a flow has a single screen, it needs no child coordinator. Revisit this ADR if more than a third of coordinator code is forwarding.

### Android (`android/app/`): MVI

Kotlin, Jetpack Compose with Material3 (stable 1.4.x, Expressive APIs behind `@OptIn(ExperimentalMaterial3ExpressiveApi::class)`; move to 1.5.x when it is stable; no beta in releases), OkHttp with kotlinx.serialization, a JSON file in `noBackupFilesDir` for the draft [v1.6 | 2026-10-28] (was DataStore; amended after slice 2, ADR-0011 v1.2). Hand-written MVI, no MVI library:

- One immutable `State` data class per screen, a sealed `Intent` (user actions) and a sealed `Effect` (one-shot events: navigate, toast).
- A pure `reduce(state, result): State` function that is unit-tested without Android.
- The `ViewModel` is the store: it takes intents, calls repositories, applies `reduce`, exposes `StateFlow<State>`; effects go through a `Channel` (collected once) or a `SharedFlow`.
- `OrderFlow` (the cross-step order state) is one store scoped to the order navigation graph and persisted as the draft (ADR-0011); step screens read it and send intents.
- Typed Navigation Compose routes. Manual DI through one `AppContainer` until the number of services or scoped lifetimes justifies Hilt.
- Packages move to `feature/{home,products,order,confirmation}`, `core/{network,data,design}` (ADR-0018 first step; the split into Gradle modules is trigger-only).

Android toolchain: the frozen version table of v1.1 to v1.3 was moved out of this ADR [v1.4 | 2026-10-27]. The current toolchain values (AGP, Kotlin, Compose BOM, Gradle, JDK, SDK levels, CI steps) live in `docs/engineering/dev-guide.md` and the Android build files (`android/gradle/libs.versions.toml` where present, `android/app/build.gradle.kts`), which change with every upgrade. What stays decided here: native Compose with Material3, AGP built-in Kotlin with the Compose compiler plugin at the Kotlin version, JDK 17, compileSdk at the level Compose requires while targetSdk stays one lower, explicit licence acceptance in CI. The table as it stood on 2026-10-26, kept for the record:

| Item | Value | Note |
| ---- | ----- | ---- |
| Android Gradle Plugin | 9.4.0 (latest stable) | Requires Gradle 9.6.0, JDK 17, build tools 36.0.0; supports up to API 37 |
| Kotlin | 2.4.21 (latest stable, released 2026-10-08) | AGP 9 has built-in Kotlin: the `org.jetbrains.kotlin.android` plugin is not applied. The Compose compiler plugin `org.jetbrains.kotlin.plugin.compose` is still applied, at the same version as Kotlin |
| Compose BOM | 2026.09.00 (newest listed) | Maps to Material3 1.4.0 and Compose UI 1.12.1, consistent with the 1.4.x rule above |
| Gradle | 9.6.0 | The minimum and default for AGP 9.4; Gradle 9.8.x also exists and may be tried later, not required |
| JDK | 17 (Temurin in CI) | `sourceCompatibility` and `targetCompatibility` 17 |
| compileSdk, targetSdk, minSdk | 37, 36, 26 [v1.2 | 2026-10-26] | compileSdk 37 is required by Compose UI 1.12.1, which BOM 2026.09.00 forces (the build fails on 36); compileSdk only selects the API used to compile, runtime behaviour follows targetSdk 36. Play target-level requirement still to be checked at submission (deployment.md section 4) |
| CI | `ubuntu-latest` (Ubuntu 24.04), `android-actions/setup-android@v3` with no packages and no automatic licence step, then `sdkmanager --licenses` and `sdkmanager "platforms;android-37.0" "build-tools;36.0.0"`, `gradle/actions/setup-gradle@v4` [v1.2 | 2026-10-26] | `.github/workflows/android.yml` |

The licence step is explicit because the action's own step exits 1 on the preview-SDK licence prompt that appears with platform 37 (observed in CI by the developer, 2026-10-26; no official source read). [v1.2 | 2026-10-26]

Not verified: whether the Compose compiler plugin at 2.4.21 composes cleanly with AGP's built-in Kotlin (the project has never been built; first CI run decides). The Gradle wrapper is still to be generated and committed.

Rules common to both:

- One `OrderFlow` state object owns the draft (items, date, slot, name, phone, address, district, note, idempotency key) and survives step navigation (FR-15): on iOS owned by the order coordinator, on Android a store scoped to the order navigation graph [v1.5 | 2026-10-27].
- Validation rules (phone, lengths, minimum quantity, date window) live in one `OrderRules` unit per platform, tested against `contracts/fixtures`.
- The server is the authority; the client never sends computed values except `expected_total_vnd` (price acknowledgement, ADR-0010).
- Strings come from resource files keyed by the UI document keys (`Localizable.xcstrings`, `res/values/strings.xml` with Vietnamese as the only language).
- Dates are shown in Vietnam time using the server date (`server_date`), not the device clock.
- Network timeout for order submission: 10 s (PRD performance); loads: 15 s.

Modularisation [v1.4 | 2026-10-27]: the folder structure above is the first stage. Whether and when it becomes separate modules or packages (iOS local packages, Android Gradle modules, backend targets) is decided in ADR-0018; until a trigger there fires, the single-module layout of this ADR stays.

## Consequences

- Positive: minimal dependencies; navigation is testable without views on iOS; Android state changes are explicit and the reducer is pure; each folder has one purpose.
- Negative (risks of the owner's choice) [v1.5 | 2026-10-27]: more types than plain MVVM (coordinator and `Route` on iOS; `State`, `Intent`, `Effect`, `reduce` per Android screen), so nine screens carry boilerplate; an iOS coordinator can become a layer that only forwards calls (condition above); Android effects delivered through a `Channel` can be lost across configuration changes if collected carelessly (collect in a lifecycle-aware scope); no ready-made DI, revisit with a new ADR if services grow (Hilt trigger above).
- Still true: manual DI, no third-party packages on iOS, `@Observable`, iOS 17.
- Follow-up: forge-dev: dev guide lists commands per platform and the new patterns; existing iOS and Android code (slice 1 and 2 screens) moves to the new structure when next edited, not in one rewrite; probe-qa: import-direction checks (ADR-0018).

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

Related: ADR-0005, ADR-0006, ADR-0011, ADR-0012, ADR-0016 (application identifiers), ADR-0018 (layering and split triggers); architecture.md section 15.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-26 | Android toolchain versions and CI runner recorded with sources (clarification only; decision unchanged). |
| 1.2 | 2026-10-26 | compileSdk 37 (Compose 1.12 requirement), targetSdk stays 36; CI installs platform 37 and accepts licences explicitly. |
| 1.3 | 2026-10-26 | CI platform package name corrected to `platforms;android-37.0` (clarification only). |
| 1.4 | 2026-10-27 | Frozen toolchain table replaced by a pointer to the dev guide and build files (table kept as a dated record); modularisation pointer to ADR-0018. |
| 1.5 | 2026-10-27 | Owner decision: iOS MVVM-C (coordinator conditions, navigation intents), Android MVI (hand-written, `OrderFlow` store scoped to the order graph), manual DI kept. Options, decision, consequences and risks rewritten; the dissenting research score is recorded. Toolchain, rules common to both and the manual-DI and no-package statements unchanged. |
| 1.6 | 2026-10-28 | Android draft store: file in `noBackupFilesDir` instead of DataStore (accepted, ADR-0011 v1.2). No other change. |
