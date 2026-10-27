# System Architecture: Backend code structure and client code structure

Part of [architecture.md](../architecture.md) (index, version, change log), sections 14, 14.1, 15. Moved from architecture.md v1.7 with the wording unchanged unless a line carries a newer label [v1.8 | 2026-10-27].

## 14. Backend Code Structure Target [v1.4 | 2026-10-26]

Review after the refactor round of slice 0 (`backend/Sources/App`, evidence read on 2026-10-26). Strengths worth keeping: configuration parsed from a dictionary and never from the global environment; secrets never echoed in errors; one place that turns any thrown error into the contract envelope; the database behind a protocol so tests need no PostgreSQL; one forward-only migration runner with a tested SQL splitter; contract fixtures decoded in tests; real-database tests that roll back. Layout as built, and the rule for each folder in slices 1 to 4:

| Folder under `Sources/App` | Holds (built) | Rule |
| -------------------------- | ------------- | ---- |
| `Config/` | `AppConfig` (variable names and defaults for `serve`), `MigrationConfig` (stage and migration URL only, used by `migrate`; `AppConfig` no longer carries the migration URL), `DatabasePoolSizing` (event loops times connections per loop stays within `DATABASE_POOL_MAX`) | Every variable of deployment.md section 3 gets a typed field when its slice reads it; `SHOP_ID` and `TRUST_PROXY` are read from slice 1 [v1.5 | 2026-10-26] |
| `Http/` | `APIError`, `APIErrorCode` (one table: code, HTTP status, top-level `message_key`; api.md section 5), `APIErrorMiddleware`, `RequestIDMiddleware`, `AccessLogMiddleware`, `RequestLimits` (body limit: Vapor rejects a body of `maxSize` bytes or more, so the configured size is 8 KB + 1 byte; exactly 8 KB passes and anything larger gets 413) | The only place that turns an error into the response envelope. Global middleware order [v1.5 | 2026-10-26]: request id, access log, error mapper, rate limiter, router (`app.middleware` is reset first, so Vapor's default error middleware is gone). The limiter sits inside the error mapper so its thrown `RATE_LIMITED` becomes the envelope and the access log sees the final status; it counts only `GET` and `HEAD`; `POST /v1/orders` limits are slice 3 and live in the order path. `APIError` carries a `headers` field that the mapper copies into the response (used for `Retry-After` and `Cache-Control: no-store`); static handlers throw the uncached not-found error (`no-store`, api.md section 4.6) so a 404 is never cached. `ClientAddress` and the limiter table are bounded as in api.md section 1 |
| `Routes/` | `HealthRoutes`; later `CatalogRoutes`, `AvailabilityRoutes`, `OrderRoutes` | Parse, call a service, encode; no SQL, no rules |
| `Services/` | `HealthService`, `ShopCalendar`, `BusinessDate`; later `AvailabilityService`, `OrderPlacementService`, `OrderRules` | Pure Swift; time, randomness and storage come in as protocols |
| `Repositories/` | `DatabaseProbe` (protocol), `PostgresProbe`, `RepositoryFactories`; later the protocols `CatalogRepository`, `DayLoadRepository`, `OrderRepository` with their PostgreSQL implementations (exact SQL of ADR-0008) | Only SQL lives here. Every method wraps connection and pool failures as `APIError(.serviceUnavailable)` (api.md section 5) |
| `Support/` | `WallClock` (protocol, `SystemWallClock`, `FixedWallClock`; named so because `Clock` is a Swift standard library protocol), `OrderCodeGenerator`, `withDeadline` | No Vapor types |
| `Migrations/` | Runner and SQL splitter | Unchanged |

Composition root: `configure` builds one `AppServices` value (`clock`, `orderCodes`, `repositories: RepositoryFactories`; `calendar` is derived from the clock; no probe member any more), stores it on the `Application`; tests replace the whole value or single members. The factories take a database handle, so slice 3 can run the `day_load` update and the order inserts in one transaction (ADR-0008); `Request.databaseHandle` is nil only when no database is configured (local runs). [v1.4 | 2026-10-26]

Error flow: services and repositories throw `APIError`; the middleware maps it (target after the review of 2026-10-27: a Vapor-free `DomainError`, section 14.1) [v1.7 | 2026-10-27]. Anything else is mapped by status when it is a Vapor `AbortError`, otherwise `INTERNAL_ERROR`, logging only the type name. The mapper never parses driver errors, so a database outage is `SERVICE_UNAVAILABLE` only when a repository throws it explicitly (api.md section 5).

Order code collisions: the generator only draws a code; the order service of slice 3 retries up to 5 draws when the unique index rejects the insert (ADR-0009).

Tests: `AppTests` is one target. Database tests (`Tests/AppTests/Database`, base class `DatabaseTestCase`) run inside that same target and only when `DATABASE_MIGRATION_URL` is set; otherwise they skip, so `swift test` works without a database. They apply the real migrations and run each test in a transaction that is rolled back. The URL must point at a throwaway database only (the CI service container or a local container), never staging or production.

Fitness for slices 1 to 3: the layering fits. Done in round 2 [v1.4 | 2026-10-26]: factories with a database handle, 8 KB body limit, `Retry-After` and `details.retry_after_seconds` written for `RATE_LIMITED` (default 60 s, the shortest window in the api.md rate-limit table), `withDeadline` cancels its timer. Still open: the access log lacks platform, app version and error code.

`withDeadline` rule [v1.4 | 2026-10-26]: its timer is a NIO scheduled task, not a sleeping Swift `Task`, because cancelling a sleeping `Task` crashed the Swift 6.2.4 release binary ("freed pointer was not the last allocation"). Debug tests never show this. Any change to `Support/Deadline.swift` needs a release-binary live check (start the release build, call the deep health check repeatedly); the CI step "Release binary smoke test" in `backend.yml` already does this, and a developer should also run it locally before merging such a change (risk R-10).

## 14.1 Layering rule, `DomainError` and the module policy [v1.8 | 2026-10-27]

Owner decision of 2026-10-27 (ADR-0018 v2.0): the layering is enforced by a test, not by discipline. The review found one leak at the type level. `APIError` and `APIErrorCode` live in `Http/` and import Vapor, yet `Services/` and `Repositories/` throw them (`Services/AvailabilityService.swift` throws `APIError(.validationFailed, fields:)`; `Repositories/DatabaseErrorTranslation.swift` rethrows as `APIError(.serviceUnavailable)`). So the rule "Services: pure Swift" is true for logic but not for the error type.

Rules (no `Package.swift` change; developer task before slice 3):

| Item | Rule |
| ---- | ---- |
| `DomainError` | A Vapor-free enum in `Support/` (cases for each business and infrastructure failure the services and repositories report: validation with field list, service unavailable, shop not found, and the order rules of slice 3). Carries no status and no message key |
| `APIErrorMiddleware` | The only place that maps `DomainError` to `APIErrorCode`, status, top-level `message_key` and body (api.md section 5); the table stays in `Http/` |
| `APIError` | Stays in `Http/` for the framework-level errors (rate limiter, body limit, not found) and as the mapped result; services and repositories no longer throw it |
| `CatalogRepositoryError` | Name is catalogue-flavoured but also thrown by the availability repository (`shopNotFound`, `sqlNotSupported`). Rename to a shared name (for example `RepositoryError`) when `DomainError` is introduced, or fold its cases into `DomainError`; developer decision, no contract effect |
| Layering test | probe-qa extends `backend/Tests/qa/Tests/QATests/RepositoryLayoutTests.swift`: no `import Vapor` or `import Fluent` in `Sources/App/Services/` and `Sources/App/Support/`; the test also fails when `Sources/App/` holds a top-level folder that is not in its list of known layers, so a new folder cannot escape the rule (Atlas specifies only; the file belongs to probe-qa) |
| Feature folders | Inside the layers: `Routes/<Feature>/`, `Services/<Feature>/`, `Repositories/<Feature>/`; no folder per feature at the top level |
| File size | At most 200 lines per file; split a service or route by responsibility before splitting a target |

Targets are not split now. Split `Package.swift` into library targets only when one trigger fires: the CI build passes about 2 to 3 minutes, a second deployable (job runner, staff API) shares the core, or agents keep breaking the layer rules despite the test. A possible shape, as a labelled sketch and not a target: `BanhCore` (pure: services, rules, `Support`, `DomainError`), `BanhPersistence` (Fluent, SQL, migrations), `BanhHTTP` (Vapor), `App` (composition root). Precondition and cost: the QA package compiles the code through a symlink to `Sources/App`; it must first depend on library products of the backend package instead, which changes the QA package (ADR-0018).

## 15. Client code structure [v1.8 | 2026-10-27]

Owner decisions of 2026-10-27 (ADR-0007 v1.5, ADR-0018 v2.0). Both apps stay one module each; folders carry the structure.

| Topic | iOS (`ios/BanhApp/`) | Android (`android/app/`) |
| ----- | -------------------- | ------------------------ |
| Pattern | MVVM-C: coordinators navigate, view models hold logic and state, views lay out | MVI: one immutable `State` per screen, sealed `Intent` and `Effect`, a pure `reduce` function |
| State holder | `@Observable` view model (iOS 17); knows no navigation and no UIKit | `ViewModel` as the store, `StateFlow<State>`; effects through a `Channel` or `SharedFlow` |
| Navigation | A coordinator owns the `NavigationPath` and the `Route` enum, builds screens, pushes, presents, dismisses, owns child coordinators | Typed Navigation Compose routes; the navigation host sits in the app layer |
| Feature to navigation | A feature gets closures or a typed intent and never imports another feature or the coordinator type | A feature emits an `Effect` (for example `NavigateToDate`); the host collects it and navigates |
| Order state across steps | `OrderFlow` owned by the order coordinator, passed to step view models | `OrderFlow` is one store scoped to the order navigation graph, persisted as the draft (ADR-0011) |
| Wiring | Manual, in the app target | Manual through `AppContainer` until services or scoped lifetimes justify Hilt |
| Import rules | A script fails CI on `Core` importing `Features`, a feature importing another feature, `Design` importing other folders | A JUnit test scans imports for the same directions (Konsist not verified) |

Coordinator condition: the coordinator stays thin (navigation only, no business logic, no network). A coordinator that only forwards calls is a smell to revisit in ADR-0007. Full reasoning, risks and the independent review that preferred plain `NavigationStack`: ADR-0007.
