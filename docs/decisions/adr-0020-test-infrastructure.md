# ADR-0020: Test infrastructure (stub backend, fakes, shared CI database)

| Field    | Value |
| -------- | ----- |
| ADR      | 0020 |
| Version  | 1.0 |
| Status   | Accepted (records decisions already built in code; none costs money or touches customer data) |
| Date     | 2026-10-27 |
| Decider  | atlas-architect (recorded after forge-dev and probe-qa built them) |
| Based on | `ios/BanhApp/Debug/UITestStub.swift`; `ios/BanhApp/App/AppEnvironment.swift:17-22`; `ios/Shared/AccessibilityID.swift:40-44`; `android/app/src/test/.../testing/Fakes.kt`, `android/app/src/androidTest/.../testing/Fakes.kt`; `.github/workflows/backend.yml`; ADR-0007, ADR-0017 |

## Context

Three test setups appeared in code without a decision record: how the iOS UI tests get data, how the Android tests get data, and how backend QA tests use PostgreSQL in CI.

## Decision

1. **iOS UI tests use an in-process stub backend**, selected by the launch argument `-BanhStubBackend <mode>` (modes: catalogue ok, unavailable). The stub replaces the `CatalogAPI` with a fake and the cache with an in-memory one; the data is fake and mirrors `contracts/fixtures/catalog-ok.json`. It is wrapped in `#if DEBUG` both in `UITestStub.swift:1` and at the only call site, `AppEnvironment.swift:17-22`. Reason: UI tests must not need a running server, must be deterministic and must not leave the app (links open through an accepting `URLOpener`).
   - Verified on 2026-10-27 by reading: `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)"` appears once in `project.pbxproj` (line 329, in the configuration whose name is `Debug` at line 332); no other occurrence, so the Release configuration does not define `DEBUG` and compiles neither the stub nor the call.
   - Not verified: that a Release archive contains no stub symbols (no archive was built or inspected in this session). A CI step is proposed: build Release for the simulator and fail if `nm` or `strings` on the binary finds `UITestStub` or `BanhStubBackend`. Route to forge-dev.
   - The argument names live in `Shared/AccessibilityID.swift` (`LaunchArgument`) so app and UI tests agree on one spelling.
2. **Android tests use repository-level fakes, not a stub HTTP backend.** Unit tests (`src/test`) and instrumented Compose tests (`src/androidTest`) use `FakeCatalogRepository`, `FakeImageLoader` (screen and view-model tests) and `FakeCatalogApi` (repository tests), passed in as constructor arguments. Reason: the Compose tests exercise screens and view models, not HTTP; the network client has its own unit tests; no HTTP server library is added (supply chain, ADR-0007). Consequence: Android has no equivalent of an end-to-end check against fixtures through the HTTP client; the shared JSON fixtures are decoded in unit tests instead (ADR-0001, R-5). If a response-handling defect escapes this, add an HTTP-level fake (OkHttp `MockWebServer`) in a new ADR version; not needed now.
3. **Backend QA uses one shared, throwaway PostgreSQL service container per CI run** (`postgres:16`, credentials valid only inside the job, `backend.yml` lines 19-41). Developer database tests run in a rolled-back transaction (`DatabaseTestCase`). The QA package runs with `QA_ALLOW_DB_MUTATION=1`: its tests may change rows (for example the number of active products) and restore the sample seed afterwards; the seed is applied twice before the run to prove it idempotent (`backend.yml:65-69`). Rule: QA mutation tests run only when `QA_ALLOW_DB_MUTATION` is set and only against a database named by `DATABASE_MIGRATION_URL` that is throwaway; never staging or production (architecture.md section 14). Tests that mutate share one database, so they must run serially and each must restore what it changed; a parallel run needs a database per test target (a change of CI, not needed now).
4. Fixtures in `contracts/fixtures/` are the shared truth for all three suites; tests decode them rather than copy values.

## Consequences

- Positive: UI tests are deterministic and offline; no extra libraries; CI database is free and disposable.
- Negative: the iOS stub reproduces the backend by hand (drift risk, mitigated by the fixture); Android has no HTTP-level end-to-end test; mutating QA tests couple to test order and to seed content.
- Follow-up: the Release-binary check in item 1; slice 3 will need stub modes for order success and each error on iOS and fakes on Android, from the order fixtures.

## Sources

| Claim | Source | Read on | Confidence |
| ----- | ------ | ------- | ---------- |
| Stub, guards and argument names | Repository files listed under "Based on" | 2026-10-27 | High (read; release binary not inspected) |

## Links

Related: ADR-0007, ADR-0001, ADR-0017; docs/engineering/dev-guide.md section 5; docs/test/place-order-tests.md.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-27 | First version (Accepted). |
