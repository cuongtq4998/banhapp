# ADR-0008: Daily-limit concurrency and idempotent order creation

| Field    | Value |
| -------- | ----- |
| ADR      | 0008 |
| Status   | Accepted |
| Date     | 2026-10-25 (v1.1 2026-10-28) |
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

Idempotency: option 1. The client creates a UUID per confirmation attempt and sends it in the `Idempotency-Key` header. The order table has a unique index on `(shop_id, idempotency_key)` and stores a SHA-256 hash of the normalised request. Same key and same hash returns the stored result (HTTP 200 with `Idempotent-Replay: true`); same key and different hash returns 422 `IDEMPOTENCY_KEY_REUSED`; two simultaneous requests with one key resolve through the unique index (the loser reads the winner's order). The key is stored with the draft (ADR-0011) so a retry after the app was killed does not create a second order. A new key is created when the order content changes (exact rule below, v1.1). Option 2 would wrongly merge two legitimate identical orders; option 3 does not meet FR-16.

**Key lifecycle and replay** [v1.1 | 2026-10-28] (clarification of the contract; the API does not change):

- The key stands for one request body. The client replaces it (new UUID v4) on every change of any body field: items, quantities, delivery date, slot, name, phone, address, district, note, and `expected_total_vnd` (also when the app, not the customer, updates the total after `PRICE_CHANGED`). Cakes dropped because they are hidden (ADR-0011) are such a change. The replacement happens at the edit, in the draft, so the saved draft always holds the key of its current content.
- The client keeps the key, unchanged, for a pure retry of the same body: `ERR_OFFLINE`, `ERR_TIMEOUT`, a lost response, 5xx, 429, `SERVICE_UNAVAILABLE`, `ORDERING_PAUSED`, and a restart of the app (the key is in the draft). It deletes the draft and key after a 201 or 200, and starts the next order with a new key. On `IDEMPOTENCY_KEY_REUSED` it replaces the key and retries once (order-lifecycle.md section 4).
- Replacing the key more often than needed is harmless, because a rejected request leaves no record. Replacing it too rarely is the defect: the server then answers 422 `IDEMPOTENCY_KEY_REUSED` or, worse, replays an older order.
- Server: the lookup is step 3 of the checks (api/03-orders.md), before date, price and capacity rules. A stored key with the same SHA-256 of the normalised body (trimmed, NFC, phone as E.164, items sorted by `product_id`, `expected_total_vnd` included) returns the original 201 body as 200 with `Idempotent-Replay: true`, even if the date has since become too soon or the price has changed, and without a new rate-limit count. A different hash returns 422 `IDEMPOTENCY_KEY_REUSED`. A key with no stored order (earlier request rejected) is processed as new. The key lives as long as the order row (unique index; no separate expiry).
- Known residual case: a timeout, then the customer edits the order and confirms again, creates a second order if the first had been stored. The customer chose a different order; the shop sees both and confirms by contact (A-6). Not prevented, by design.

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

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version (Accepted). |
| 1.1 | 2026-10-28 | Key lifecycle: when the client replaces the key, when it keeps it, replay behaviour. Clarification, no contract change. |
