# ADR-0002: Database

| Field    | Value |
| -------- | ----- |
| ADR      | 0002 |
| Status   | Proposed (pending owner choice; escalated: customer data, hard to reverse) |
| Date     | 2026-10-25 |
| Decider  | Product owner (recommendation by atlas-architect) |
| Based on | product/place-order.md v1.2 (BR-1, AC-22, BR-12); ADR-0008 |

## Context

The database holds customer personal data (name, phone, address) and enforces the daily limit under concurrent orders (BR-1, AC-22). Later slices add staff, configuration and order handling on the same data.

## Decision Drivers

- Correct concurrency for the daily limit with simple code.
- Constraints, triggers and transactions to enforce rules in the database (standard 04 rule 4).
- Cost near zero at this size; managed backups.
- Reversibility: standard SQL, common dump format.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. PostgreSQL (managed, e.g. Neon free plan or any host) | Row-level locking; `UPDATE ... WHERE` re-evaluation under concurrency is documented; CHECK constraints, triggers, `timestamptz`; portable dump; many hosts | Free plan suspends compute when idle (cold start); free storage is small |
| B. SQLite on the server disk (single instance) | No separate service; zero cost | One instance only; backup and disk loss risk on PaaS ephemeral disks; hard to scale to staff features |
| C. Cloudflare D1 (SQLite) | Very cheap | Daily write caps on free plan; single-primary; fewer interactive-transaction features; vendor tie |
| D. MySQL/MariaDB | Common | No advantage over A; weaker constraint support in older versions |
| E. Document store | Flexible | Capacity counter and constraints need application code; no gain |

## Decision (recommended: option A)

PostgreSQL 16 or newer (use the highest version the host offers; no features beyond 14 are required). The daily limit uses an atomic conditional `UPDATE` on a counter row (ADR-0008); status rules and the cancellation release use a trigger (order-lifecycle.md section 6). Times are `timestamptz` (UTC), money is `integer` VND.

## Consequences

- Positive: the rules in `data-model.md` are enforced by constraints; direct SQL cannot break them.
- Negative: free managed plans suspend idle compute; the first request after idle can be slow (mitigation in deployment.md section 7).
- Follow-up: migrations in `backend/db/migrations`; nightly encrypted dump (deployment.md section 6); data location choice in ADR-0003.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| In Read Committed, a blocked `UPDATE` re-evaluates its WHERE clause on the updated row after the other transaction commits; `INSERT ... ON CONFLICT DO UPDATE` either inserts or updates | https://www.postgresql.org/docs/current/transaction-iso.html | 2026-10-25 | High |
| Neon free plan: 0.5 GB per project, compute suspends after 5 minutes idle (cannot be disabled on free) | https://neon.com/pricing | 2026-10-25 | Medium (secondary summaries disagree on some limits) |
| Supabase free projects pause after 1 week of inactivity; Pro is USD 25 per month | https://supabase.com/pricing.md | 2026-10-25 | Medium |
| Cloudflare D1 free tier: 100,000 rows written per day | https://developers.cloudflare.com/d1/platform/pricing/ | 2026-10-25 | Medium |

## Links

Related: ADR-0001, ADR-0003, ADR-0008.
