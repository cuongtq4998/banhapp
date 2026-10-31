# Backend

Swift 6 and Vapor 4 (ADR-0001). Source of truth for the contract: `docs/system/api.md`; configuration names: `.env.example`.

## Layout

| Path | Content |
| ---- | ------- |
| `Sources/App/configure.swift`, `AppServices.swift`, `entrypoint.swift` | Composition root: `configure` builds middleware and one `AppServices` value (clock, order code generator, repository factories) stored on the `Application` |
| `Sources/App/Config/` | `AppConfig` (variable names, defaults), `MigrationConfig`, `DatabasePoolSizing` |
| `Sources/App/Http/` | `APIError` and `APIErrorCode` (api.md section 5), error, request-id, access-log and rate-limit middleware (`FixedWindowRateLimiter`), `EntityTag` (ETag), static file responder |
| `Sources/App/Routes/` | One `RouteCollection` per endpoint group (`HealthRoutes`, `CatalogRoutes`, `AvailabilityRoutes`, `OrderRoutes`, `AssetRoutes`, `PrivacyRoutes`) |
| `Sources/App/Services/` | Rules: `HealthService`, `CatalogService`, `ShopCalendar`, `BusinessDate` |
| `Sources/App/Repositories/` | SQL behind protocols (`DatabaseProbe`, `CatalogRepository`) with their PostgreSQL implementations, `RepositoryFactories`, and `translatingDatabaseErrors` (driver failure to `SERVICE_UNAVAILABLE`) |
| `Sources/App/Support/` | `WallClock`, `OrderCodeGenerator`, `withDeadline` |
| `Sources/App/Migrations/` | SQL file runner (`SQLFileMigration`, `SQLScriptSplitter`) |
| `assets/` | `privacy.html` (served at `/privacy`) and `images/*.png` (served at `/assets/images/...`; fake placeholders only). Copied into the image next to the binary |
| `db/migrations/` | Forward-only `NNNN_name.sql` files |
| `db/seed/sample.sql` | Fake sample shop data, idempotent |
| `Tests/AppTests/` | Unit tests (XCTest, XCTVapor) |
| `Tests/AppTests/Database/` | Trigger and catalogue SQL tests against a real PostgreSQL; skipped unless `DATABASE_MIGRATION_URL` is set |
| `Dockerfile` | Multi-stage image; build context is the repository root |

Conventions: a route parses and encodes, a service decides, a repository runs SQL; time, randomness and storage enter through `AppServices`; repositories are factories taking a database handle (`RepositoryFactories`), so a service can run several in one transaction (ADR-0008). Tests replace a member, for example `app.services.stubDatabaseProbe { ... }` or `app.services.clock = ...` (or the whole value). A new endpoint group is a new `RouteCollection` registered in `configure`; a new error is a case of `APIErrorCode`.

Logging policy (auth.md): access log lines carry method, route template, status, duration, request id, error code, platform and app version only (platform and version are logged only when they match a strict pattern, else `-`); unexpected errors log the error type, never its text. Keep it that way in new code.

Every repository method wraps its work in `translatingDatabaseErrors`: connection and pool failures become `APIError(.serviceUnavailable)`, a statement the server rejects stays an internal error. Every GET shares one per-client budget in a fixed 60 s window (`RATE_LIMIT_READ_PER_MINUTE`; a 429 does not count; the window length is `AppConfig.rateLimitWindowSeconds`, shortened by tests). `image_url` carries `?v=` with the first 8 hex of the file's SHA-256, computed at start (`AssetVersions`), and images are served immutable for a year; behind a proxy set `TRUST_PROXY=true`, which makes the limiter use the last `X-Forwarded-For` entry.

Orders: `OrderRoutes` parses, `OrderPlacementService` decides, `PostgresOrderRepository` runs the ADR-0008 transaction; limits and the pause switch are `OrderPolicy` (`ORDERING_ENABLED`, `RATE_LIMIT_ORDER_PER_HOUR`, `ORDER_MAX_PER_PHONE_PER_DAY`). Order database tests commit rows (fake shop per test); use a throwaway database.

Database tests: set `DATABASE_MIGRATION_URL` to a throwaway database (they apply the migrations, then run every test in a rolled-back transaction). Without it they are skipped.

Admin sign-in (slice B1, `docs/system/api/05`): `AuthRoutes` (`/v1/auth/code-requests`, `/sessions`, `/refresh`) and `AdminRoutes` (`/v1/admin/me`, `DELETE /v1/admin/session`, `DELETE /v1/admin/sessions/others`) sit in `Routes/Admin/`; services in `Services/Admin/Auth/` (`CodeRequestService`, `SignInVerifyService`, `SessionService`, the pure time rules in `AuthRules`) and `Services/Admin/Mail/` (`EmailSender`, `MailDispatcher`); SQL in `Repositories/Admin/AuthStore*`. Every route under `/v1/admin` or `/v1/owner` must be opened with `adminGroup()` or `ownerGroup()` (`Routes/Admin/AdminRouteGroups.swift`): they add `AdminAuthMiddleware` (opaque 300 s access token, checked against the session row on every request) and `RequireRole`; `RoleCoverageTests` fails for a route that lacks the role check. Limits are counted in the database (30 s resend, 3 codes an hour per address, 5 wrong entries void a code, no address lock) plus an in-memory limit per client address. Mail leaves after the response through `MailDispatcher` (one retry, failure logged without the address). Sign-in is off (`/v1/auth` answers 503) unless `AUTH_CODE_PEPPER` and `EMAIL_PROVIDER` are both set. Operator command: `APP_ENV=local DATABASE_URL=<url> SHOP_ID=<uuid> swift run App create-owner --email <address> [--name <name>]` (creates the one owner; the output never repeats the address). The admin database tests (`Tests/AppTests/Admin/*`, the ones that extend `AdminDatabaseTestCase`) commit rows into a fresh shop per test, so use a throwaway database.

## Commands (run in `backend/`)

```
swift build
swift test
APP_ENV=local PORT=8080 swift run App serve        # GET http://localhost:8080/healthz
docker compose up -d db                             # local PostgreSQL
APP_ENV=local DATABASE_MIGRATION_URL=<url> swift run App migrate --yes   # needs only APP_ENV and DATABASE_MIGRATION_URL
APP_ENV=local DATABASE_URL=<url> SHOP_ID=<uuid> swift run App create-owner --email <address>   # first owner (after migrate and seed)
psql "<url>" -f db/seed/sample.sql                  # sample data, local and staging only
docker build --platform linux/amd64 -f backend/Dockerfile .   # from the repository root
```

Database URLs use the standard PostgreSQL URI form with the scheme `postgres`, then user, password, host, port and database name; take the local values from `docker-compose.yml`. Never commit real URLs.

Configuration per command: `serve` needs `APP_ENV`, `PORT` and (outside local) `DATABASE_URL` and `SHOP_ID`; `migrate` needs only `APP_ENV` and `DATABASE_MIGRATION_URL`; `create-owner` needs `APP_ENV`, `DATABASE_URL` and `SHOP_ID`. The command is the first argument that does not start with `-`, as in Vapor, so `App --yes migrate` and `App --env staging migrate` select `migrate`. Values are trimmed of whitespace and newlines.

Migration files: the SQL splitter understands standard and `E'...'` strings, quoted identifiers, dollar quoting (opened only where PostgreSQL lexes it, not inside an identifier such as `a$b$c`) and nested comments. Anything else that holds a `;` inside a single statement is not supported.
