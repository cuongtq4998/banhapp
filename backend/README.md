# Backend

Swift 6 and Vapor 4 (ADR-0001). Source of truth for the contract: `docs/system/api.md`; configuration names: `.env.example`.

## Layout

| Path | Content |
| ---- | ------- |
| `Sources/App/` | Application code (`configure.swift`, `HealthRoute.swift`, `AppConfig.swift`) |
| `Sources/App/Migrations/` | SQL file runner (`SQLFileMigration`, `SQLScriptSplitter`) |
| `db/migrations/` | Forward-only `NNNN_name.sql` files |
| `db/seed/sample.sql` | Fake sample shop data, idempotent |
| `Tests/AppTests/` | Unit tests (XCTest, XCTVapor) |
| `Dockerfile` | Multi-stage image; build context is the repository root |

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
