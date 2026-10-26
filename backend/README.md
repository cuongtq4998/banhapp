# Backend

Swift 6 and Vapor 4 (ADR-0001). Source of truth for the contract: `docs/system/api.md`; configuration names: `.env.example`.

## Layout

| Path | Content |
| ---- | ------- |
| `Sources/App/configure.swift`, `AppServices.swift`, `entrypoint.swift` | Composition root: `configure` builds middleware and one `AppServices` value (clock, database probe, order code generator) stored on the `Application` |
| `Sources/App/Config/` | `AppConfig` (variable names, defaults), `DatabasePoolSizing` |
| `Sources/App/Http/` | `APIError` and `APIErrorCode` (api.md section 5), error, request-id and access-log middleware |
| `Sources/App/Routes/` | One `RouteCollection` per endpoint group (`HealthRoutes`) |
| `Sources/App/Services/` | Rules: `HealthService`, `ShopCalendar`, `BusinessDate` |
| `Sources/App/Repositories/` | SQL behind protocols (`PostgresProbe`) |
| `Sources/App/Support/` | `WallClock`, `OrderCodeGenerator`, `DatabaseProbe`, `withDeadline` |
| `Sources/App/Migrations/` | SQL file runner (`SQLFileMigration`, `SQLScriptSplitter`) |
| `db/migrations/` | Forward-only `NNNN_name.sql` files |
| `db/seed/sample.sql` | Fake sample shop data, idempotent |
| `Tests/AppTests/` | Unit tests (XCTest, XCTVapor) |
| `Tests/AppTests/Database/` | Trigger tests against a real PostgreSQL; skipped unless `DATABASE_MIGRATION_URL` is set |
| `Dockerfile` | Multi-stage image; build context is the repository root |

Conventions: a route parses and encodes, a service decides, a repository runs SQL; time, randomness and storage enter through `AppServices`. Tests replace a member with `app.services.databaseProbe = ...` (or the whole value). A new endpoint group is a new `RouteCollection` registered in `configure`; a new error is a case of `APIErrorCode`.

Logging policy (auth.md): access log lines carry method, route template, status, duration and request id only; unexpected errors log the error type, never its text. Keep it that way in new code.

Database tests: set `DATABASE_MIGRATION_URL` to a throwaway database (they apply the migrations, then run every test in a rolled-back transaction). Without it they are skipped.

## Commands (run in `backend/`)

```
swift build
swift test
APP_ENV=local PORT=8080 swift run App serve        # GET http://localhost:8080/healthz
docker compose up -d db                             # local PostgreSQL
APP_ENV=local PORT=8080 DATABASE_MIGRATION_URL=<url> swift run App migrate --yes
psql "<url>" -f db/seed/sample.sql                  # sample data, local and staging only
docker build --platform linux/amd64 -f backend/Dockerfile .   # from the repository root
```

Database URLs use the `postgres://user:password@host:5432/db` form; take the local values from `docker-compose.yml`. Never commit real URLs. <!-- secret-scan:allow -->
