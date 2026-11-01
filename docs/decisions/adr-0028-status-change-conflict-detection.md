# ADR-0028: Detecting a stale view when an order status changes

| Field    | Value |
| -------- | ----- |
| ADR      | 0028 |
| Version  | 1.5 [v1.5 | 2026-11-01] (deviation D-1 fixed in slice B6; earlier: built in B3, replay beyond the window, R-1) |
| Status   | Accepted (no money, no new customer data) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD admin-orders v1.6 FR-16 to FR-19, BR-2, AC-25 to AC-29 (ids as in product/admin-orders/08, section 15); TQ-5; order-lifecycle.md |

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

Window note [v1.2 | 2026-10-31]: the order lookup uses the window function of ADR-0029 v1.3: an open order of any age can be changed; a repeat after the change is a replay while the order is inside the window (finished orders stay 90 days after they were placed). An order placed more than 90 days ago and closed today leaves the window; v1.3 [v1.3 | 2026-11-01] (R-1): the status route finds the order by code without the window and applies the window only after the replay test. Rule: (1) order not found: 404; (2) the replay test below passes: 200 with `Idempotent-Replay: true`, even if the order is now outside the window (the owner who lost the reply of a close sees no error, FR-19); (3) otherwise an order outside the window answers 404 (no detail of a hidden order is ever returned, so 409 `details.order` is never built for it); (4) otherwise the normal checks. A replay is only an exact repeat by the same account of the last change, so it reveals nothing new. Retry rule: if zero rows are updated, the current status equals `to_status`, and the latest `status_changed` event came from the same account with `from_status = expected_status`, the call returns 200 with `Idempotent-Replay: true` and the current detail (a repeated tap or a lost response). Any other combination stays 409, including a different person reaching the same target (AC-29 keeps the refusal for a different action; the same target by another person is also 409 so that history is never misattributed).

## Consequences

- Positive: no schema change for conflicts; the database guard stays the last defence.
- Negative: the client must send the status it saw; a client defect that sends the wrong value gets 409 and refreshes.
- Follow-up: tests of two parallel requests (one 200, one 409), replay, invalid pair, final states.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Compare-and-set in a single UPDATE is atomic under PostgreSQL READ COMMITTED (the second writer re-checks the WHERE clause after the first commits) | https://www.postgresql.org/docs/current/transaction-iso.html (section 13.2.1) | from memory, not fetched | Medium |


Built in slice B3 [v1.4 | 2026-11-01]: the order of checks, the compare-and-set, the replay rule (same account, current status equals the target, last event `from_status` equals `expected_status`) and the 409 body are built as written. One deviation was found, defect D-1: the code looked the order up through the window first, so the replay rule of v1.3 (200 after the order left the window) answered 404. Status: fixed in B6 [v1.5 | 2026-11-01]; `AdminOrderService.changeStatus` falls back to a lookup without the age limit and answers the exact repeat with 200 and `Idempotent-Replay: true`; any other call on such an order stays 404 and builds no `details.order`. Field codes of the body (`UNKNOWN_FIELD`, `STATUS_INVALID`, `REASON_NOT_ALLOWED`): api/08 section 11.1.

## Links

Related: ADR-0008, ADR-0030. Detail: admin-order-handling.md, api/06.
