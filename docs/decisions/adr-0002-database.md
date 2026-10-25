# ADR-0002: Database

| Field    | Value |
| -------- | ----- |
| ADR      | 0002 |
| Version  | 1.1 |
| Status   | Accepted (owner decision, 2026-10-25) [v1.1 | 2026-10-25] |
| Date     | 2026-10-25 (v1.1 2026-10-25) |
| Decider  | Product owner |
| Based on | product/place-order.md v1.2 (BR-1, AC-22, BR-12); ADR-0008 |

## Context

The database holds customer personal data (name, phone, address) and enforces the daily limit under concurrent orders (BR-1, AC-22). Later slices add staff, configuration and order handling on the same data.

## Decision Drivers

- Correct concurrency for the daily limit with simple code.
- Constraints, triggers and transactions to enforce rules in the database (standard 04 rule 4).
- Cost near zero at this size; backups possible.
- Reversibility: standard SQL, common dump format.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. PostgreSQL (managed) | Row-level locking; `UPDATE ... WHERE` re-evaluation under concurrency is documented; CHECK constraints, triggers, `timestamptz`; portable dump; many hosts; first-class Swift driver (PostgresNIO) | Free plans suspend idle compute (cold start); free storage is small |
| B. SQLite on server disk | No service | Single instance; ephemeral disks on PaaS |
| C. Cloudflare D1 | Cheap | Write caps; vendor tie |
| D. MySQL/MariaDB | Common | No advantage |
| E. Document store | Flexible | Counter and constraints in application code |

## Decision [v1.1 | 2026-10-25]

**PostgreSQL**, accepted by the owner. Version: the highest the host offers; nothing beyond version 14 is required. The daily limit uses an atomic conditional `UPDATE` on a counter row (ADR-0008); status rules and the cancellation release use a trigger (order-lifecycle.md section 6). Times are `timestamptz` (UTC), money is `integer` VND. The Swift backend reaches it through PostgresNIO (via Fluent's Postgres driver, ADR-0001); the schema does not depend on Fluent conventions. Fluent migration wrappers execute plain SQL files. The application connects with a direct (not pooled) connection string because PgBouncer transaction mode conflicts with prepared statements (unverified for this driver; keep direct connections and a small pool, `DATABASE_POOL_MAX`).

## Consequences

- Positive: rules in `data-model.md` are enforced by constraints; direct SQL cannot break them.
- Negative: free managed plans suspend idle compute; the first query after idle can be slower (ADR-0003, deployment.md section 7).
- Follow-up: migrations in `backend/db/migrations`; nightly encrypted dump (deployment.md section 6); data location in ADR-0003.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| In Read Committed, a blocked `UPDATE` re-evaluates its WHERE clause on the updated row after the other transaction commits | https://www.postgresql.org/docs/current/transaction-iso.html | 2026-10-25 | High |
| Neon free plan: 1 GB storage per project, 100 CU-hours per month, suspend after 5 minutes idle (cannot be changed on free), 6-hour restore window | https://neon.com/docs/introduction/plans | 2026-10-25 | High |
| Fluent PostgreSQL driver is built on PostgresKit and PostgresNIO | https://github.com/vapor/fluent-postgres-driver | 2026-10-25 | Medium |
| PgBouncer transaction mode and prepared statements conflict with this driver | Architect knowledge; not verified | 2026-10-25 | Unverified |

## Links

Related: ADR-0001, ADR-0003, ADR-0008.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | Proposed. |
| 1.1 | 2026-10-25 | Owner accepted PostgreSQL; Swift driver notes; free plan limits updated from Neon docs. |
