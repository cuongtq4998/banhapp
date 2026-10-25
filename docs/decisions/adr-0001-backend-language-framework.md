# ADR-0001: Backend language and framework

| Field    | Value |
| -------- | ----- |
| ADR      | 0001 |
| Version  | 1.1 |
| Status   | Accepted (owner decision, 2026-10-25) [v1.1 | 2026-10-25] |
| Date     | 2026-10-25 (v1.1 2026-10-25) |
| Decider  | Product owner |
| Based on | product/place-order.md v1.2; Q-T1, Q-T5 |

## Context

The slice needs a small HTTP JSON backend: read shop data, compute date availability, accept an order inside one database transaction. Expected load is tiny (architecture.md section 8). Later slices add staff login (one-time code), order handling and owner configuration. The architect recommended TypeScript on Node.js (v1.0). [v1.1 | 2026-10-25] The owner decided on **Swift with Vapor**, overriding that recommendation; this version records the owner's choice and its real trade-offs.

## Decision Drivers

- Low running cost and low operations effort for a small shop.
- Strong typing and validation of request bodies.
- One language family with the iOS app (shared contract types, same developer skills). [v1.1 | 2026-10-25]
- Hosting must remain reversible (any container host).

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. TypeScript on Node.js (Fastify, zod, `pg`) | Largest hosting support and ecosystem; small image | A language unrelated to the mobile apps. Not chosen |
| B. Kotlin with Ktor | Same language as Android | JVM memory on small hosts. Not chosen |
| C. Swift with Vapor | Same language as the iOS app; contract types can be shared; strong typing and async/await; small runtime image | Smaller ecosystem and hiring pool; long cold compile; Swift on Linux friction (see Consequences). **Chosen by the owner** |
| D. Go | Small binary | A third language. Not chosen |
| E. Cloudflare Workers with D1 | Cheapest idle | Different runtime and database. Not chosen |

## Decision [v1.1 | 2026-10-25]

Swift (6.x toolchain; the current release on swift.org is 6.4.1 as of 2026-10-25, verified) with **Vapor 4** (latest stable 4.122.3 on GitHub, read 2026-10-25; Vapor 5 is in beta and is not used until stable). Details:

- Database access: **Fluent with `fluent-postgres-driver`** (built on PostgresKit and PostgresNIO) for catalogue reads and migrations; **raw parameterised SQL through Fluent's `SQLDatabase`/PostgresNIO** for the order transaction, so the atomic capacity statement of ADR-0008 stays visible and testable. Fluent models are not used for `customer_order` writes. Reason: Fluent is the framework-standard path and is maintained by the Vapor team; the order path needs exact SQL.
- Migrations: forward-only SQL files in `backend/db/migrations/` executed by Fluent migration wrappers (`SQLDatabase.raw`) so Fluent records applied versions (data-model.md section 8).
- Validation: explicit validation code in the backend (one function per rule) returning the field error codes of api.md; unknown request fields are rejected by a key check before decoding (Swift `Codable` ignores unknown keys by default).
- Time: Vietnam business dates use a fixed UTC+7 offset (no daylight saving, A-1), so the runtime image needs no time zone database.
- Rate limiting: a small in-memory middleware (no mature maintained Vapor package was assumed; unverified).
- Tests: XCTest with `XCTVapor`, run in CI on Linux against a PostgreSQL service container. Lint: SwiftLint (or swift-format). forge-dev records the final choice in the dev guide.
- Container: multi-stage Dockerfile (Swift toolchain image to build, slim Ubuntu image to run, static Swift standard library), image built for `linux/amd64`.
- **Shared contracts package**: a small SwiftPM library `BanhContracts` in `contracts/swift/` holding the request, response and error-code types (Foundation only, no Vapor). The backend imports it (adding Vapor `Content` conformances locally) and the iOS app uses it as a local package; Android keeps its own Kotlin types checked against the same JSON fixtures in `contracts/fixtures/`. The package is optional for the iOS team: if it causes friction the iOS app may keep its own types, the JSON fixtures remain the single contract test.

## Consequences [v1.1 | 2026-10-25]

Trade-offs of server-side Swift for a small shop:

- Ecosystem and people: much smaller than Node or Go; fewer libraries (SMS one-time code, push notifications for later slices may need hand-written REST clients) and fewer developers to hire. Mitigation: the later needs are plain HTTPS calls; Vapor and its drivers are actively maintained (Vapor 4.122.3 released October 2026).
- Hosting: no host offers Swift-specific runtimes; every free or cheap host is reached by a Docker image. This is fine because ADR-0003 uses a container image.
- Build time and memory: compiling Swift in release mode is slow. Reports: about 8 minutes for a Vapor Docker build on GitHub Actions, 25 minutes on Apple silicon building an x86 image, a release build exceeding a 10-minute trial limit on a PaaS, and a memory-kill (`signal 9`) report; all from older Swift versions and anecdotal; no current benchmark was found (unverified). Mitigation: **build in GitHub Actions, never on the hosting platform**, with dependency caching; the host only pulls the finished image (ADR-0003). Developers build natively on macOS for daily work.
- Linux differences: code that compiles on macOS may use APIs missing in Foundation on Linux; CI must build and test on Linux for every pull request.
- Version churn: Swift 6 strict concurrency and the Vapor 4 to 5 move will cost migration effort; pin versions in `Package.resolved` and plan one upgrade review per year.
- Positive: contract types shared with iOS; one language for the iOS and backend developers; strong typing.
- Follow-up: repository path `backend/` (ADR-0004); the architecture, deployment, api conventions, data-model migrations and repo layout are rewritten for Vapor (architecture.md v1.1, deployment.md v1.1). The data model and the API shapes do not change.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Vapor latest stable 4.122.3 (21 Oct), 5.0 beta 4 marked Latest | https://github.com/vapor/vapor/releases | 2026-10-25 | Medium (year not shown on page) |
| Vapor docs version menu: 4.0 latest, 5.0 alpha | https://docs.vapor.codes/ | 2026-10-25 | Medium |
| Swift 6.4 released 2026-09-15; install shows 6.4.1 | https://www.swift.org/blog/ | 2026-10-25 | High |
| Fluent PostgreSQL driver uses PostgresKit over PostgresNIO; README shows a Swift 6.2+ badge | https://github.com/vapor/fluent-postgres-driver | 2026-10-25 | Medium |
| Vapor Docker deployment uses a two-stage Dockerfile; builds must run in Linux | https://docs.vapor.codes/deploy/docker/ | 2026-10-25 | Medium |
| Build time reports: 25 min on Apple silicon, 8 min on GitHub Actions; signal 9 failure; 10-minute PaaS limit exceeded | https://forums.swift.org/t/how-to-distribute-a-vapor-project/53831 ; https://forums.swift.org/t/vapor-build-with-docker-takes-too-long/69032 ; https://station.railway.com/questions/build-time-timeout-7a2e5dfa | 2026-10-25 | Low (old Swift versions, anecdotes) |
| Ecosystem size, hiring pool, no mature rate-limit package | Architect knowledge; not researched | 2026-10-25 | Unverified |

## Links

Supersedes: v1.0 recommendation (TypeScript). Related: ADR-0002, ADR-0003, ADR-0004, ADR-0007.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | Proposed, TypeScript recommended. |
| 1.1 | 2026-10-25 | Owner chose Swift with Vapor; Accepted; trade-offs, stack details and shared contracts package added. |
