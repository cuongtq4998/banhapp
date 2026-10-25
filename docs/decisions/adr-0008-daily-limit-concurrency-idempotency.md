# ADR-0008: Daily-limit concurrency and idempotent order creation

| Field    | Value |
| -------- | ----- |
| ADR      | 0008 |
| Status   | Accepted |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | PRD Q-T1; BR-1, BR-9, FR-16, AC-19, AC-22, AC-28 |

## Context

Two customers may confirm at the same moment for the last cakes of a date (AC-22). A customer may tap twice or retry after a timeout (AC-19). Cancellation, built later, must return cakes (BR-9). The rule "total cakes per date never exceeds the limit" must hold even if code has a bug.

## Decision Drivers

- Correctness under concurrency with the least moving parts.
- The rule must be enforced by the database (standard 04 rule 4).
- A retry after an unknown outcome (timeout) must be safe.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Counter row per date (`day_load`) changed by one conditional `UPDATE ... WHERE cakes_accepted + n <= limit`; CHECK constraint backs it | One statement; row lock serialises orders of one date; correct under Read Committed; O(1) | Counter must follow every status change (done by trigger) |
| B. `SELECT sum(...)` over orders inside a transaction with an advisory or table lock | No counter | Locks wider than needed; sum scans; easy to forget the lock |
| C. SERIALIZABLE isolation with retry on conflict | No explicit lock | Retry loops; harder to test; serialization failures under load |
| D. Check in application memory | Simple | Wrong with more than one instance or restart; rejected |

Idempotency options: (1) client-generated key in header, unique column on the order; (2) server-side deduplication by hash of phone, date and items within a time window; (3) none (UI blocks double taps only).

## Decision

Capacity: option A.

1. In the order transaction, `INSERT INTO day_load (shop_id, delivery_date, cakes_accepted, capacity_limit) VALUES (..., 0, :limit) ON CONFLICT DO NOTHING`.
2. `UPDATE day_load SET cakes_accepted = cakes_accepted + :n, capacity_limit = :limit WHERE shop_id = :s AND delivery_date = :d AND cakes_accepted + :n <= :limit`. Zero rows updated means the date cannot hold the order: roll back and return `DATE_CAPACITY` (409).
3. CHECK `cakes_accepted >= 0 AND cakes_accepted <= capacity_limit` on the table protects against code defects.
4. A trigger on the order table decrements the counter when status becomes `Cancelled` (BR-9, AC-28) in the same transaction as the status change.
5. A second order on the same date blocks on the row lock until the first commits and then re-evaluates the WHERE clause on the new row version (documented PostgreSQL behaviour), so exactly one of two competing orders succeeds (AC-22).

Idempotency: option 1. The client creates a UUID per confirmation attempt and sends it in the `Idempotency-Key` header. The order table has a unique index on `(shop_id, idempotency_key)` and stores a SHA-256 hash of the normalised request. Same key and same hash returns the stored result (HTTP 200 with `Idempotent-Replay: true`); same key and different hash returns 422 `IDEMPOTENCY_KEY_REUSED`; two simultaneous requests with one key resolve through the unique index (the loser reads the winner's order). The key is stored with the draft (ADR-0011) so a retry after the app was killed does not create a second order. A new key is created when the customer changes the order content. Option 2 would wrongly merge two legitimate identical orders; option 3 does not meet FR-16.

Order of work in the transaction: validate, check rules, check price acknowledgement, take capacity last, insert order and items, commit. Failures before the capacity step take no lock.

## Consequences

- Positive: both properties are guaranteed by the database; simple to test with parallel requests.
- Negative: raising the limit later does not change old `capacity_limit` values until an order touches that date (the available-dates query reads the current limit from settings, not from the row).
- Follow-up: a reconciliation query (`day_load` versus sum of non-cancelled orders) is part of the test plan.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Read Committed: after waiting for a concurrent updater the WHERE clause is re-evaluated on the updated row; `INSERT ... ON CONFLICT DO UPDATE` inserts or updates | https://www.postgresql.org/docs/current/transaction-iso.html | 2026-10-25 | High |
| Idempotency-Key header: key must be unique and not reused with a different payload | https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-idempotency-key-header | 2026-10-25 | Medium (draft; status codes 409/422 not confirmed in the current draft) |

## Links

Related: ADR-0002, ADR-0009, ADR-0011.
