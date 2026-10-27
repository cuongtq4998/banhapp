# ADR-0018: Layering, file size and when each component splits into packages

| Field    | Value |
| -------- | ----- |
| ADR      | 0018 |
| Version  | 2.0 [v2.0 \| 2026-10-27] |
| Status   | Accepted by owner decision 2026-10-27. Replaces version 1.0 (Accepted earlier the same day), which had a calendar of extractions |
| Date     | 2026-10-27 |
| Decider  | Owner (decisions 3, 4, 5 of 2026-10-27); atlas-architect (writing, open gaps) |
| Based on | ADR-0004, ADR-0005, ADR-0007 v1.5; `/CLAUDE.md` "Project rule: file size"; architecture.md sections 14, 15; code read on 2026-10-27; a research review of version 1.0 (summarised below) |

## Context

Each component is one build unit: `ios/BanhApp` (one app target; folders `App`, `Core/{Catalog,Contact,Design,Localization,Network,Support}`, `Features/{Home,Launch,Order,Products}`), `android/app` (one Gradle module; packages `data`, `design`, `ui/*`), `backend/Sources/App` (one SwiftPM target). Separate packages today: `contracts/swift` (`BanhContracts`) and the QA package. Production code is about 2,000 lines per client, so full modularisation costs more than it returns (the Android guide says the same; source below). What can go wrong without a boundary is erosion, not size. Couplings found on 2026-10-27:

| Where | Coupling |
| ----- | -------- |
| Android `design/StateViews.kt:19,25` | The design package imports the app's `TestTags` and generated `R` |
| Android `ui/common/` | Generic helpers (`Money`, `ImageSampling`, `RefreshWhenResumed`) sit next to catalogue code (`CatalogViewModel`, `LoadFailureText`) |
| iOS `Core/Design`, `Core/Network` | Nothing stops a feature importing another feature, or `Core` importing a feature |
| Backend `Http/APIError.swift` | `APIError` imports Vapor but services and repositories throw it (`Services/AvailabilityService.swift:46`, `Repositories/DatabaseErrorTranslation.swift`) |

A review of version 1.0 found: its symmetric target map (iOS three packages plus feature targets, Android about eight Gradle modules, backend four targets) was a mirror for its own sake; its calendar ("extract at the start of slice 3") was an event unrelated to any failure; the iOS clean-build trigger (3 minutes) cannot fire at this size; and four gaps were open (below). The owner kept the direction and replaced the calendar by triggers.

## Decision Drivers

- Pay for a boundary only when it prevents a real failure (erosion, build time, ownership).
- Small shop, few developers, free CI minutes; no build-system machinery without a trigger.
- A split must not change behaviour, the scheme name `BanhApp` or the project file format 77.
- Files stay small by responsibility (200 lines); that is the first and cheapest modularity.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Flat, folders only | Zero cost | Boundaries are convention; nothing fails when a coupling appears |
| B. Flat, boundaries enforced by tests, split on triggers only (chosen) | Nearly free; catches erosion in CI; keeps the option of a split | Tests check imports, not access; someone must watch the triggers |
| C. Full split now (symmetric module map, calendar) | Compiler-enforced direction | Large up-front cost for about 2,000 lines; unverified Compose compiler behaviour in library modules; QA symlink blocks the backend split; version 1.0, rejected by the owner |

## Decision

Option B. Rule for all components: **a feature never depends on another feature; dependencies point inward to shared code; the app or `App` target is the composition root; every hand-written file is at most 200 lines, so split files by responsibility first; module or package splits stay trigger-based.**

### Decision 3: backend (owner, as proposed)

- A Vapor-free `DomainError` in `Support/` carries every failure that services and repositories report. `APIError` and `APIErrorCode` stay in `Http/`, and `APIErrorMiddleware` maps `DomainError` to them (api.md section 5).
- Layering is enforced by a test in `backend/Tests/qa/Tests/QATests/RepositoryLayoutTests.swift` (probe-qa writes it): no `import Vapor` or `import Fluent` in `Sources/App/Services/` or `Sources/App/Support/`. The test also fails on unknown top-level folders under `Sources/App/` (known list: `Config`, `Http`, `Migrations`, `Repositories`, `Routes`, `Services`, `Support`), so a new folder cannot escape the rule.
- Feature folders live inside the layers (`Routes/<Feature>/`, `Services/<Feature>/`, `Repositories/<Feature>/`). No target split now; `Package.swift` is unchanged.

### Decision 5: package and module policy (trigger-only)

| Component | Now | First step when a trigger fires | Triggers |
| --------- | --- | ------------------------------- | -------- |
| iOS | One app target. A CI script checks import directions inside `ios/BanhApp`: `Core` never imports `Features`; a feature never imports another feature; `Design` imports no other folder | `BanhCore` first: pure logic (`OrderRules`, `OrderFlow`, `Load`, repository protocols) as a local package with `swift test`. `BanhDesign` later or never. No `BanhFeatures` package: removed from the map until a trigger names it | A second app target or extension needs shared code; a second developer joins; a measured incremental build above about 30 s; repeated import violations that the script cannot stop. The 3-minute clean-build trigger is dropped (it cannot fire here) |
| Android | One module. First remove the two couplings above (design takes the test tag and strings as parameters; `ui/common` splits into generic helpers and catalogue code), then lay out `feature/*` and `core/*` packages inside the module, and add a JUnit import-direction test | Gradle modules, `:core:*` first, features second; convention plugins in `build-logic` only with 4 or more library modules (Gradle recommends them over `allprojects`; source below). A spike on one module comes first | A second app (staff or owner) needs the design system; a second developer joins. Compose recomposition or stability problems never trigger a split |
| Backend | One target, layering test as above | Library targets. The QA package must first depend on library products of the backend package instead of the symlink `backend/Tests/qa/Sources/AppUnderTest -> Sources/App` (`backend/Tests/qa/Package.swift:23-35`). Cost: the QA package is rewritten, and one symlink-based test layout disappears | CI build above about 2 to 3 minutes; a second deployable (job runner, staff API) shares the core; agents keep breaking layer rules despite the test |

The earlier symmetric map is kept only as a sketch, not a target: iOS `BanhCore` / `BanhDesign` / app; Android `:core:model`, `:core:network`, `:core:data`, `:core:designsystem`, `:feature:catalog`, `:feature:order`, `:app`; backend `BanhCore` / `BanhPersistence` / `BanhHTTP` / `App`. It shows where seams would go; nothing is built from it before a trigger.

### Open gaps from the review, closed

| Gap | Answer |
| --- | ------ |
| How a feature asks the coordinator to navigate (iOS) | Each feature owns a small intent enum (for example `ProductListIntent.openDetail(productID)`) and receives a closure `(Intent) -> Void` from the coordinator at construction. The coordinator maps intents to `Route` values. A feature never imports another feature, the coordinator type or `Route`. Tested with a fake closure. Detail and condition: ADR-0007 |
| Where the Android order state lives | One `OrderFlow` store scoped to the order navigation graph (a `ViewModelStoreOwner` from `navController.getBackStackEntry(<order graph route>)`, manual factory), persisted as the draft (ADR-0011). Step screens read it and send intents; they do not own copies. Not verified on a device |
| Dependency injection | iOS and Android: manual, through the app target and `AppContainer`. Hilt only when the number of services or scoped lifetimes makes `AppContainer` hard to read (decision recorded in ADR-0007) |
| Failure modes of a Swift package at extraction | See the next list; each item is checked in a spike before the first package exists |
| Konsist | Not verified (the project's docs site did not resolve; README summary only). The default is a plain JUnit test that reads `src/main/kotlin/**/*.kt`, extracts `import` lines and asserts the direction table. Konsist may replace it later if verified |
| Import test passes on unknown folders | Every import check (iOS script, Android JUnit test, backend test) fails when it finds a top-level folder or package it does not know, so adding code in a new place forces a decision |

Before extracting any iOS package (mitigations, none applies today):

- `package` access (SE-0386): use it between targets of one package and `public` only at a boundary another package consumes. This relaxes the dev-guide rule "public only for `BanhContracts`" (routed query below). Check in the spike that tests with `@testable import` still work.
- Default actor isolation (SE-0466, Swift 6.2): the app target uses `MainActor`; a package does not inherit it. Set `defaultIsolation` per target in `Package.swift`: pure logic `nonisolated`, UI targets `MainActor`. Keep the Swift language mode explicit per target and equal to the app's.
- `Bundle.module`: a package that holds resources needs its own bundle and lookups. Keep `Localizable.xcstrings` and assets in the app target; a package must not read strings. Verify with a test that fails when a resource lookup is nil.
- Do not change the project file format 77 or the scheme name; add local packages to the existing project. A pure-Swift test target per package replaces app-hosted tests for rules and flow; UI tests stay in `BanhAppUITests` (ADR-0020).

## Consequences

- Positive: the cheap controls (tests, scripts, one error-type move, small files) land at once; splits happen only for a measured reason; no premature symmetry.
- Negative: boundaries are checked by import tests, which can miss an `import` in an unexpected file type; the triggers need someone to look at build times; the QA package change is deferred, not avoided.
- Not verified: Android Gradle Plugin 9.4 built-in Kotlin with the Compose compiler plugin in library modules (the migration page is silent); Konsist; the Android back-stack-entry store pattern on this app.
- Follow-up: forge-dev: `DomainError`, the iOS import script, Android relocation of couplings and the JUnit test, the dev-guide `public` rule (dev guide belongs to forge-dev). probe-qa: the backend layering test. Orchestrator: `scripts/file-size-baseline.txt` loses the entries of the four split system documents.
- Migration order if a trigger fires: amend this ADR first, then spike, then extract one package.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Modularising a project that will not grow may be too complex for its benefit | https://developer.android.com/topic/modularization | 2026-10-27 | High |
| `package` access modifier (SE-0386, Swift 5.9) | https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md | 2026-10-27 | High |
| `defaultIsolation` per target, only that target's code, default nonisolated (SE-0466, Swift 6.2) | https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md | 2026-10-27 | High |
| Gradle: use convention plugins instead of `allprojects` | https://docs.gradle.org/current/userguide/sharing_build_logic_between_subprojects.html | 2026-10-27 | High |
| Konsist runs as unit tests, `assertArchitecture` | https://github.com/LemonAppDev/konsist | 2026-10-27 | Medium (README only); not relied on |
| AGP built-in Kotlin; page silent on the Compose compiler plugin | https://developer.android.com/build/migrate-to-built-in-kotlin | 2026-10-27 | High; Compose question unverified |
| Couplings and current layout | Repository files in the Context table | 2026-10-27 | High |
| Review of version 1.0 | Owner summary in the task of 2026-10-27, not re-read | 2026-10-27 | Medium |

## Links

Related: ADR-0004, ADR-0007, ADR-0001, ADR-0011, ADR-0020; [architecture.md](../system/architecture.md) sections 11, 14, 15.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-27 | First version (Accepted). Symmetric target map and calendar of extractions. |
| 2.0 | 2026-10-27 | Rewritten after owner decisions 3, 4, 5: trigger-only split policy, symmetric map reduced to a sketch, iOS `BanhFeatures` removed, triggers fixed per platform, backend `DomainError` and layering test confirmed (fails on unknown folders), 200-line file rule, open gaps closed (navigation intents, Android order store, DI, package failure modes, JUnit instead of Konsist). Status Accepted by owner. |
