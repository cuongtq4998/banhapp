# ADR-0018: Modular package architecture and when each component splits

| Field    | Value |
| -------- | ----- |
| ADR      | 0018 |
| Version  | 1.0 |
| Status   | Accepted (direction and triggers). No module is created by this ADR except where section "Schedule" says so |
| Date     | 2026-10-27 |
| Decider  | atlas-architect |
| Based on | ADR-0004, ADR-0005, ADR-0007; architecture.md section 14; code read on 2026-10-27 (paths below); owner request of 2026-10-27 to study a package architecture for iOS with similar patterns for Android and the backend |

## Context

Each component is one build unit today: `ios/BanhApp` (one app target, folders `App`, `Core/{Catalog,Contact,Design,Localization,Network,Support}`, `Features/{Home,Launch,Order,Products}`), `android/app` (one Gradle module, packages `data`, `design`, `ui/*`), and `backend/Sources/App` (one SwiftPM target, folders in architecture.md section 14). The only separate packages are `contracts/swift` (`BanhContracts`) and the QA package. The layering inside each component is sound. The size is about 2,000 lines of production code per client, so full modularisation would cost more than it returns today (the Android guide says the same: modularising a project that will not grow may be too complex for the benefit; source below).

What can go wrong without a boundary is not size but erosion: a folder rule is kept only by discipline. Hidden couplings found on 2026-10-27:

| Where | Coupling |
| ----- | -------- |
| Android `design/StateViews.kt:19,25` | The design package imports the app's `TestTags` and the app's generated `R` |
| Android `ui/common/` | Generic helpers (`Money`, `ImageSampling`, `RefreshWhenResumed`) sit next to catalogue code (`CatalogViewModel`, `LoadFailureText`) |
| iOS `Core/Design` and `Core/Network` | Imported by features, but nothing stops a feature importing another feature or `Core` importing a feature |
| Backend `Http/APIError.swift` | `APIError` and `APIErrorCode` live in the HTTP folder (they import Vapor) but services and repositories throw them (`Services/AvailabilityService.swift:46`, `Repositories/DatabaseErrorTranslation.swift`). The layer rule "Services have no Vapor types" is therefore broken at the type level for errors |

## Decision Drivers

- Keep the three components symmetrical so one description fits all (ADR-0007 driver).
- Pay for a boundary only when it prevents a real failure (erosion, build time, ownership), not before.
- Small shop, few developers, free CI minutes: no build-system machinery without a trigger.
- A split must not change the app's behaviour, the scheme name or the project file format (CLAUDE.md: format 77, scheme `BanhApp`).

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Stay flat: one module per component, folders only | Zero cost; nothing to migrate | Boundaries are only convention; the Android couplings above exist already and nothing fails when a new one appears |
| B. Flat now, enforce direction by tests (import-direction script on iOS, Konsist-style test on Android, layout test on backend), split into modules lazily on a trigger | Nearly free; catches erosion in CI; keeps the option of a split | Tests are weaker than a compiler boundary (they check imports, not access) |
| C. Full split now (iOS 3 local packages and a feature target each; Android about 8 Gradle modules; backend 4 targets) | Compiler-enforced direction; faster incremental builds later; clear ownership | Large up-front cost for about 2,000 lines; Android convention plugins and Compose compiler behaviour in library modules unverified; backend QA package symlink blocks it (below); more files per feature |
| D. Hybrid (chosen): B everywhere now, plus a staged compiler boundary where it is cheap and the benefit is concrete | See Decision | Needs the triggers below to be watched |

## Decision

Option D. Rule for all components: **feature folders live inside a few stable modules; a feature never depends on another feature; dependencies point inward to shared core; the app or `App` target is the composition root.**

### Target module map (parallel across components)

| Role | iOS (local SwiftPM packages under `ios/Packages/`, plus the existing `contracts/swift`) | Android (Gradle modules) | Backend (SwiftPM targets) |
| ---- | ----- | ----- | ----- |
| Composition root | App target `BanhApp`: `App/`, navigation `Route` enum, string catalog, assets | `:app` | `App` (tiny: `configure`, `AppServices`, routes wiring) |
| Pure domain and rules | `BanhCore`: `OrderRules`, `OrderFlow`, `Load`, repository protocols | `:core:model` (plain JVM) | `BanhCore` (no Vapor, no Fluent): services, rules, `WallClock`, `DomainError` |
| Network and data | `BanhCore` (network client, catalogue data) in step 1; split `BanhData` only on trigger T-3 | `:core:network`, `:core:data` | `BanhPersistence` (Fluent, SQL, migrations) |
| Delivery layer | n/a | n/a | `BanhHTTP` (Vapor: routes, middleware, `APIErrorMiddleware`) |
| Design system | `BanhDesign`: tokens, components, fonts; depends on nothing of ours | `:core:designsystem`; `:core:ui` for generic helpers | n/a |
| Features | `BanhFeatures`: one target per feature (`Home`, `Products`, `Order`, ...) | `:feature:catalog`, `:feature:order` | folders `Routes/<Feature>` and `Services/<Feature>` |
| Test support | `BanhCore` product `BanhCoreTestSupport` (fakes, fixture loading) | `:core:testing` | test target helpers |
| Shared contract | `BanhContracts` (existing) | Kotlin types checked against `contracts/fixtures/` | `BanhContracts` (existing) |

### Dependency direction (allowed imports; anything not listed is forbidden)

| From | May depend on |
| ---- | ------------- |
| iOS app target | `BanhFeatures`, `BanhDesign`, `BanhCore`, `BanhContracts` |
| iOS feature target | `BanhDesign`, `BanhCore`, `BanhContracts`; never another feature, never the app target |
| `BanhDesign` | system frameworks only |
| `BanhCore` | `BanhContracts`, system frameworks; never `BanhDesign`, never features |
| Android `:app` | every module |
| Android `:feature:*` | `:core:*`; never another feature |
| `:core:designsystem` | system and Compose only (no app `R`, no `TestTags`) |
| `:core:data`, `:core:network` | `:core:model` |
| `:core:model` | Kotlin and kotlinx.serialization only |
| Backend `App` | `BanhHTTP`, `BanhPersistence`, `BanhCore` |
| `BanhHTTP` | `BanhCore`, Vapor |
| `BanhPersistence` | `BanhCore`, Fluent, SQL drivers |
| `BanhCore` | `BanhContracts`, Foundation only |

### When each component splits

| Component | Now (this ADR) | Next step | Trigger for the next step |
| --------- | -------------- | --------- | ------------------------- |
| iOS | Add a CI script that checks import directions inside `ios/BanhApp` (folder rules of the table: `Core` never imports `Features`; a feature folder never imports another feature folder; `Design` imports no other folder). Fix nothing else | Extract `BanhDesign`, then `BanhCore`, then one feature target at a time, at the start of the slice that edits that feature (slice 3 starts with `Design` and `Core`; see architecture.md section 11) | T-1: a second developer or a second app target needs the design system or core; or T-2: a clean incremental build of the app target exceeds 3 minutes locally; or T-3: a rule violation the script cannot express |
| Android | First remove the two hidden couplings (design no longer imports the app `R` or `TestTags`: pass the test tag and strings in as parameters; split `ui/common` into generic helpers and catalogue code). Add a Konsist-style direction test (Konsist `assertArchitecture`, source below) | Modules in the map above, `:core:*` first, features second. Convention plugins in `build-logic` only when there are 4 or more library modules (Gradle recommends convention plugins over `allprojects`/`subprojects`, source below) | Same T-1 and T-2, measured with Gradle build scans or timing; plus T-4: a Compose stability or recomposition problem is not an argument for a split, so it never triggers one |
| Backend | Introduce a Vapor-free `DomainError` (the `APIErrorCode` table stays in `Http/`, which maps `DomainError` to the envelope in `APIErrorMiddleware`) and a layout test asserting that no file under `Services/` or `Support/` imports `Vapor` or `Fluent`. No `Package.swift` change | Split into `BanhCore`, `BanhPersistence`, `BanhHTTP`, `App`. Decide first how the QA package consumes the code (see Consequences) | Revisit at the start of slice 3 (order creation, the first transaction across repositories); split earlier only on T-5: a second delivery mechanism (job runner, staff API with another middleware stack) needs the core without Vapor |

Concurrency and access rules for iOS packages (to apply at extraction, none apply today):

- Use the `package` access level (SE-0386, Swift 5.9) for symbols shared between targets of one package, instead of widening to `public`; `public` only at the boundary a different package consumes. This relaxes the dev-guide rule "public only for the `BanhContracts` package" to "public only at package boundaries" (the dev guide belongs to forge-dev; routed query below).
- The app target sets `MainActor` as the default actor isolation. Packages do not inherit it: set `defaultIsolation` per target in each `Package.swift` (SE-0466, Swift 6.2, per target, only affects the target's own code, source below). Pure logic targets stay `nonisolated`; UI targets (`BanhDesign`, `BanhFeatures`) use `MainActor`.
- The app is built in Swift 5 language mode; a package declaring tools version 6 would compile in Swift 6 mode. Declare the language mode per target explicitly and keep it equal to the app's until the app moves.
- Keep `Localizable.xcstrings` in the app target until the last step (a package needs its own resource bundle and `Bundle.module` lookups; cost with no benefit for a single language).
- Do not change the project file format (`objectVersion 77`) or the scheme name `BanhApp`; local packages are added to the existing project.
- A pure-Swift test target in each package replaces app-hosted tests for rules and flow; UI tests stay in `BanhAppUITests` (ADR-0020).

## Consequences

- Positive: the cheap controls (scripts, tests, one error-type move) land at once and stop the erosion; compiler-enforced boundaries arrive exactly where work happens, one slice at a time; the three components stay describable with one table.
- Negative: until a split happens the boundaries are checked by tests of imports, which a determined developer can sidestep by an `import` in an unexpected file type; the triggers need someone to look at build times.
- The backend QA package compiles the backend through a symlink `backend/Tests/qa/Sources/AppUnderTest -> Sources/App` (`backend/Tests/qa/Package.swift:23-35`, `path: "Sources/AppUnderTest"`). A symlink to one folder cannot follow a split into several targets. Before the backend split, the QA package must depend on the backend's library products instead (a path dependency on `backend/` exposing `BanhCore`, `BanhPersistence` and `BanhHTTP` as library products, with the executable target kept separate), which changes probe-qa's package. The QA package is owned by probe-qa; this ADR only states the precondition.
- The backend layout test and the QA package belong to probe-qa: `backend/Tests/qa/Tests/QATests/RepositoryLayoutTests.swift` should gain the assertion "no `import Vapor` or `import Fluent` in `Sources/App/Services/` and `Sources/App/Support/`". Atlas specifies it; probe-qa writes it.
- Not verified: Android Gradle Plugin 9.4 built-in Kotlin together with the Compose compiler plugin in library modules (the migration page says nothing about the Compose compiler plugin; source below), and Compose stability across module boundaries. A spike on one module is the first Android step, before any other module moves.
- Follow-up for the orchestrator or forge-dev: the dev-guide rule on `public`, the import-direction script (iOS), the Konsist test (Android), `DomainError` (backend).
- Migration order if the triggers fire: ADR amendment (this ADR, new version) first, then iOS `BanhDesign`, `BanhCore`, features; Android spike, `:core:*`, features; backend after the QA package decision.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Modularising a project that will not grow may be too complex for its benefit; too fine-grained modules add build complexity and boilerplate | https://developer.android.com/topic/modularization | 2026-10-27 | High |
| `package` access modifier: visible to other modules of the same package, hidden from clients outside it (SE-0386, implemented in Swift 5.9) | https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md | 2026-10-27 | High |
| `defaultIsolation` is set per target in `swiftSettings` (PackageDescription 6.2), applies only to that target's own code, default is nonisolated (SE-0466, Swift 6.2) | https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md | 2026-10-27 | High |
| Gradle: avoid `allprojects`/`subprojects` for shared build logic; use convention plugins | https://docs.gradle.org/current/userguide/sharing_build_logic_between_subprojects.html | 2026-10-27 | High |
| Konsist runs as unit tests and checks layer dependency rules with `assertArchitecture` | https://github.com/LemonAppDev/konsist | 2026-10-27 | Medium (README summary; the project's own docs site did not resolve) |
| AGP built-in Kotlin: migration steps; the page does not mention the Compose compiler plugin | https://developer.android.com/build/migrate-to-built-in-kotlin | 2026-10-27 | High (for what it says); the Compose question stays unverified |
| Hidden couplings and current layout | Repository files cited in the Context table | 2026-10-27 | High |

## Links

Related: ADR-0004 (layout), ADR-0007 (mobile architecture), ADR-0001 (backend, contracts package), ADR-0020 (test infrastructure); architecture.md sections 11 and 14.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-27 | First version (Accepted). |
