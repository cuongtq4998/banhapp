# ADR-0028: Detecting a stale view when an order status changes

| Field    | Value |
| -------- | ----- |
| ADR      | 0028 |
| Version  | 1.1 [v1.1 | 2026-10-31] |
| Status   | Accepted (no money, no new customer data) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD FR-16 to FR-19, BR-2, AC-26 to AC-30; TQ-5; order-lifecycle.md |

## Context

Two staff may open the same order. The second action from an out-of-date view must be refused, the stored order left unchanged, and the current state shown. The database already allows only four transitions and never leaves a final state.

## Decision Drivers

- Exact, race-free, no new lock.
- A lost response must not produce a confusing error for the person who acted.
- Simple for both apps.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Client sends `expected_status`; one conditional `UPDATE ... WHERE status = expected` (chosen) | Status only moves forward, so equal status means an equal version; no extra column | Cannot detect changes that leave the status equal (none exist: nothing else about an order is editable) |
| B. Version column and `If-Match` ETag | General | A column and header for no extra protection here |
| C. `SELECT ... FOR UPDATE`, then decide | Familiar | Longer lock; same result |

## Decision

Option A. Body `{ "expected_status", "to_status", "cancel_reason" }`. Order of checks: session and role; order found inside the 90-day window (else 404 `ORDER_NOT_FOUND`); fields valid (`CANCEL_REASON_REQUIRED` for `Cancelled` without a reason, a reason with any other target is `VALIDATION_FAILED`); `(expected_status, to_status)` is an allowed pair (else 422 `STATUS_TRANSITION_INVALID`, no write); then one transaction sets `app.actor_type`, `app.actor_id`, `app.actor_name` with `set_config(..., true)` and runs `UPDATE customer_order SET status, cancel_reason, updated_at WHERE id AND status = expected_status`. Zero rows updated means someone else moved the order: 409 `ORDER_STATE_CHANGED` with the current order detail in `details.order`, nothing changed. The triggers write the event and release capacity in the same transaction.

Window note [v1.2 | 2026-10-31]: the order lookup uses the window function of ADR-0029 v1.2; an old unfinished order can be closed, and after it is closed a repeat answers 404 (it is outside the window), not a replay. Retry rule: if zero rows are updated, the current status equals `to_status`, and the latest `status_changed` event came from the same account with `from_status = expected_status`, the call returns 200 with `Idempotent-Replay: true` and the current detail (a repeated tap or a lost response). Any other combination stays 409, including a different person reaching the same target (AC-30 keeps the refusal for a different action; the same target by another person is also 409 so that history is never misattributed).

## Consequences

- Positive: no schema change for conflicts; the database guard stays the last defence.
- Negative: the client must send the status it saw; a client defect that sends the wrong value gets 409 and refreshes.
- Follow-up: tests of two parallel requests (one 200, one 409), replay, invalid pair, final states.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Compare-and-set in a single UPDATE is atomic under PostgreSQL READ COMMITTED (the second writer re-checks the WHERE clause after the first commits) | https://www.postgresql.org/docs/current/transaction-iso.html (section 13.2.1) | from memory, not fetched | Medium |

## Links

Related: ADR-0008, ADR-0030. Detail: admin-order-handling.md, api/06.
