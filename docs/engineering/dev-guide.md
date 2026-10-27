# Developer Guide

| Field        | Value |
| ------------ | ----- |
| Version      | 1.5 |
| Last updated | 2026-10-27 |
| Status       | Draft |
| Owner        | forge-dev (orchestrator wrote the first version) |
| Based on     | architecture.md v1.1; ADR-0001, 0004, 0005, 0007; slice 0 code |
| Related      | `backend/README.md`; `docs/system/deployment.md` |

Every command below was run on the author's machine unless the line says "unverified". Slices 0 and 1 (backend): health check, empty app shells, first migration, read-only catalogue, assets, privacy page, read rate limit. [v1.1 | 2026-10-26] Slice 2 (backend): `GET /v1/availability`. [v1.4 | 2026-10-27]

## 1. Prerequisites

| Tool | Version | Needed for | Verified here |
| ---- | ------- | ---------- | ------------- |
| Swift | 6.2 | backend, contracts | yes |
| Xcode | 26.x or 27 (project format 77; do not commit Xcode 27's upgrade to 110, hosted CI has 26.x) | iOS | yes (27.1 beta) |
| Docker | current | local PostgreSQL, image build | no (not installed) |
| PostgreSQL client (`psql`) | 16 | seed and migrations | no |
| JDK | 17 | Android | no |
| Android SDK | platform 37.0 (`platforms;android-37.0`), build-tools 36.0.0, cmdline-tools | Android | no |
| Gradle | 9.6.0 (only to create the wrapper once) | Android | no |

## 2. Repository Layout

| Path | Responsibility |
| ---- | -------------- |
| `ios/` | SwiftUI app, iPhone only, iOS 17 |
| `android/` | Kotlin and Compose app, minSdk 26, package `app.banh.customer` (ADR-0016) |
| `backend/` | Vapor API; `Sources/App`, `Tests/AppTests`, `db/migrations`, `db/seed`, `Dockerfile` |
| `contracts/` | Shared fixtures (`fixtures/`) and the `BanhContracts` Swift package (`swift/`) |
| `docs/` | Product, design, system, decisions, engineering, test, pipeline |
| `.github/workflows/` | CI: `backend.yml`, `ios.yml`, `android.yml` |
| `.claude/` | Agents, skills, rules, hooks for the feature pipeline |

## 3. Setup & Run

Backend (`backend/`):

```
swift build
swift test
APP_ENV=local PORT=8080 swift run App serve     # then GET http://localhost:8080/healthz
APP_ENV=local PORT=8080 SHOP_ID=00000000-0000-4000-8000-000000000001 DATABASE_URL=<local url> swift run App serve   # unverified against PostgreSQL: GET /v1/catalog, /privacy, /assets/images/banana.png [v1.1 | 2026-10-26]
docker compose up -d db                          # unverified: local PostgreSQL
APP_ENV=local PORT=8080 DATABASE_MIGRATION_URL=<local url> swift run App migrate --yes   # unverified
psql "<local url>" -f db/seed/sample.sql         # unverified; fake data only
```

Configuration names are in `backend/.env.example`; the local URL values are in `backend/docker-compose.yml`.

iOS (`ios/`; replace the Xcode path with one from `ls /Applications | grep Xcode`):

```
export DEVELOPER_DIR=/Applications/<Xcode 27>.app/Contents/Developer
xcodebuild -project BanhApp.xcodeproj -scheme BanhApp -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

iOS configuration [v1.2 | 2026-10-26]: the API address is the build setting `API_BASE_URL` (default `http://localhost:8080` in `ios/Config/Project.xcconfig`; override it in the git-ignored `ios/Config/Local.xcconfig`, see the `.example` file; write `//` as `/$()/`). It reaches the app through `ios/Config/Info.plist` (`BanhAPIBaseURL`). UI tests run against an in-process stub chosen by the debug-only launch argument `-BanhStubBackend catalog|unavailable`; accessibility identifiers live in `ios/Shared/AccessibilityID.swift`, compiled into the app and the UI test target.

Android (`android/`), unverified: create the wrapper once with `gradle wrapper --gradle-version 9.6.0`, commit it, then `./gradlew :app:assembleDebug`.

Availability (slice 2, backend) [v1.4 | 2026-10-27]: `GET /v1/availability?cakes=N` needs `SHOP_ID` like the catalogue (without it: 503) and shares the read rate-limit budget. `AvailabilityRoutes` parses `cakes`, `AvailabilityService` applies lead time, horizon and capacity (rules written once, with the Vietnam date from the injected `ShopCalendar`), `AvailabilityRepository` (protocol) and `PostgresAvailabilityRepository` hold the read-only SQL on `shop_setting`, `product` and `day_load`. No migration: the slice reads existing tables. Tests inject `FakeAvailabilityRepository` and `FixedWallClock`; `Tests/AppTests/Database/AvailabilityRepositoryTests.swift` runs the SQL and needs `DATABASE_MIGRATION_URL` (skipped otherwise). The shared fixture is `contracts/fixtures/availability-ok.json`. `cakes` errors use field code `CAKES_INVALID` with key `ERR_SERVER` (not yet named in api.md).

## 4. Coding Conventions

Principles every change must meet (the owner asked for code that stays easy to maintain and grow through the next slices):

| Principle | In this codebase |
| --------- | ---------------- |
| Single responsibility | One type, one reason to change. Routes parse and respond; rules live in services; SQL lives in repositories. |
| Dependency inversion at the edges | Database, clock, HTTP and random sources are protocols passed in by the composition root, so tests replace them (see `DatabaseProbe`). |
| Open for extension | A new rule or endpoint is a new type or file, not a branch added to a shared function. |
| DRY and no magic values | Names, limits and texts come from constants, configuration or the contract; business rules are written once on the server and checked by shared fixtures on the clients. |
| Make invalid states unrepresentable | Enums and typed ids instead of strings and flags; no boolean parameters that switch behaviour. |
| Explicit errors | Typed errors mapped once to the API error catalogue; error text never carries secrets or customer data. |
| Small public surface | `internal` by default, `public` only for the `BanhContracts` package. |
| Testability | Every rule has a unit test; time and concurrency are injected, not read from globals. |
| Small files | At most 200 lines per hand-written file (source, tests, documents); split by responsibility, never by trimming. Generated files are exempt. [v1.5 \| 2026-10-27] |

Naming: verb plus a specific object (`loadCatalog`, not `setupData`). Comments are English and explain why. Layering: iOS and Android follow ADR-0007; the backend follows `docs/system/architecture.md`. Rules for Swift files: `.claude/rules/swift.md`.

## 5. Testing

| Where | Command | Notes |
| ----- | ------- | ----- |
| Backend and contracts unit tests | `swift test` in `backend/` and in `contracts/swift/` | XCTVapor; no database needed (the database tests skip without `DATABASE_MIGRATION_URL`) [v1.1 \| 2026-10-26] |
| Database behaviour | CI job `backend / test` against a `postgres:16` service | First real run of `0001_init.sql` happens in CI |
| iOS | `xcodebuild ... -destination "platform=iOS Simulator,id=<id>" -parallel-testing-enabled NO test` in `ios/` | Without the flag the run fails with "No matching device ... XCTestDevices" |
| Android | `./gradlew :app:testDebugUnitTest` | Unverified |
| Contract fixtures | `contracts/fixtures/*.json` decoded by every suite | Add a fixture with every contract change |

## 6. Branching & Commits

- Branch `feature/<slug>`; stage branches `stage/<slug>/<n>-<agent>` stay local.
- Conventional Commits in English (`feat(backend): ...`); no secrets, real hostnames, personal data or work emails in commits (public repository). Commit author must be the noreply address.
- Pull request: summary, links to the PRD and the test report, real test results, assumptions, open risks. The owner merges.

## 7. Troubleshooting

| Problem | Fix |
| ------- | --- |
| Xcode says the project cannot be opened (format 110) | `objectVersion` must stay 77; set it back by hand if Xcode 27 upgraded it |
| iOS test run: "No matching device ... XCTestDevices" | Add `-parallel-testing-enabled NO` |
| UI test cannot find Vietnamese text | The project development region must be `vi` |
| Release build of the backend crashed on the deep health check | Fixed by the rewritten `withDeadline`; keep the live `?deep=1` check in CI and report any recurrence |
| `App migrate` refuses to start | Set `DATABASE_MIGRATION_URL`; the error names the variable, never its value |
| `iPhone 16` simulator missing | Pick any installed iPhone: `xcrun simctl list devices available` |

## 8. Known Gaps (slice 0)

- Catalogue SQL (`PostgresCatalogRepository`) has never run against PostgreSQL on the author's machine; only CI runs it. The CI database tests and the smoke test (which sets `SHOP_ID` and checks `/v1/catalog`) now run it on every push. [v1.3 | 2026-10-27]
- Docker image, `0001_init.sql` on PostgreSQL, seed and the live deep health check have never run; the first CI run is the verification.
- Android has never been built (no JDK, Gradle, SDK on the author's machine); Gradle wrapper missing.
- Apple `DEVELOPMENT_TEAM` is no longer in the repository: copy `ios/Config/Local.xcconfig.example` to the git-ignored `ios/Config/Local.xcconfig` to sign for a device; unsigned builds need no file.
- Startup warning for sample rows in production (ADR-0013) is left to slice 4.

## 9. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-26 | First version after slice 0 merged. |
| 1.1 | 2026-10-26 | Slice 1 backend: `SHOP_ID` for `serve`, catalogue, assets, rate limit; catalogue SQL not yet run against PostgreSQL. |
| 1.2 | 2026-10-26 | Slice 1 iOS: `API_BASE_URL`, stub backend launch argument, shared accessibility identifiers. |
| 1.3 | 2026-10-27 | Known gaps: catalogue SQL and `SHOP_ID` smoke check are covered by CI. |
| 1.4 | 2026-10-27 | Slice 2 backend: availability endpoint, `day_load` read SQL, fixture `availability-ok.json`. |
| 1.5 | 2026-10-27 | Principle added: at most 200 lines per file. |
