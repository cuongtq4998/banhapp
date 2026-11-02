# ADR-0033: Six-step order process, expected delivery date and final delivery fee

| Field    | Value |
| -------- | ----- |
| ADR      | 0033 |
| Version  | 1.3 [v1.3 | 2026-11-02] (clarifications, Decision 12; v1.2: date range, fee correction; v1.1: event history kept, cutover decision) |
| Status   | Accepted (the owner approved the PRD change on 2026-11-02; no money, no new customer data) |
| Date     | 2026-11-02 |
| Decider  | atlas-architect |
| Based on | PRD admin-orders v1.10 (BR-2, BR-9, BR-11, BR-15, FR-13, FR-16 to FR-19, FR-28, FR-29, AC-26 to AC-29, AC-49 to AC-52), place-order v1.7; product/admin-orders/09 |
| Supersedes in part | ADR-0028 (the pair table and the compare key; the rest stays), ADR-0029 (the definition of "unfinished" and the list sort key; the 90-day window stays) |

## Context

The order process grows from four statuses to six. Two new facts are stored: an expected delivery date that moves while the status stays, and the real delivery fee entered at "Start delivery". ADR-0028 relied on "status only moves forward, so equal status means equal version"; a date move breaks that.

## Decision

1. Statuses (text, English identifiers): `Received`, `Processing`, `DeliveryDateScheduled`, `DeliveryStarted`, `Finished`, `Cancelled`. Transition table and side effects: order-process.md. Old rows: `customer_order.status` is remapped New to Received, Confirmed to Processing, Completed to Finished (assumption Q-35); Cancelled stays. `order_event` is NOT rewritten [v1.1 | 2026-11-02]: it is append-only (0006) and an audit record; old events keep the words New, Confirmed, Completed, Cancelled forever, the API and apps map them when reading history, new events use the new words. No `order_event` CHECK names status words, so none changes; the protection trigger stays untouched (data-model/06 section 5).
2. Compare-and-set key. Status changes keep `UPDATE ... WHERE status = :expected_status`. A date move has no status change, so its key is the pair `(status = 'DeliveryDateScheduled', expected_delivery_date = :previous_expected_delivery_date)`. Zero rows updated means 409 `ORDER_STATE_CHANGED` with the current detail. Replay rule: zero rows, the current date equals the requested date, and the latest date-change record has the same account and `old_date = previous` returns 200 with `Idempotent-Replay: true`.
3. The customer-chosen `delivery_date` stays untouched and alone holds `day_load` (BR-15). Only `Cancelled` releases capacity, as today. The expected date is never checked against limit, lead days or slots; only "not before the shop's today" and a valid date.
4. District fee: `customer_order.delivery_fee_vnd` and `total_vnd` stay as the stored estimate (immutable, BR-6) so the customer API and old customer apps do not change (`expected_total_vnd` still equals cakes plus estimate). The real fee is a new nullable column; amount to collect = `items_subtotal_vnd + delivery_fee_final_vnd`, computed by the API, null until the fee is entered. Rejected: overwriting `delivery_fee_vnd` (breaks the immutability trigger and the total CHECK).
5. List date = `COALESCE(expected_delivery_date, delivery_date)`; unfinished = status in the four open steps and list date <= shop today (ADR-0029 supersession). Window rule unchanged: open orders any age, `Finished` and `Cancelled` 90 days after placed.
6. Every date entry and move is a row in `order_expected_date_change` (account id and name snapshot, time, old and new date), written in the same transaction by the same statement path that sets the date.
7. Cancel is allowed only from `Received` and `Processing`.
8. Migration `0008_order_process.sql`, forward-only, preceded by `pg_dump` (data-model/06). It is not additive: the status values change, so the old backend release cannot run on it (see Old clients).

9. Expected date range [v1.2 | 2026-11-02] (owner decision A): the date must be from the shop's today to today + 7 inclusive, "today" on the Asia/Ho_Chi_Minh calendar, never in the past. Checked on every entry and every move, in the API only (a CHECK cannot use the clock). Moves are unlimited. Codes `EXPECTED_DATE_PAST`, `EXPECTED_DATE_TOO_FAR`. An idempotent replay (Decision 2) is answered 200 before the range is checked again, so a retry after midnight is not refused.
10. Fee correction [v1.2 | 2026-11-02] (owner decision B): staff and owner (the same roles as every status change, api/05) may change `delivery_fee_final_vnd` only while status is `DeliveryStarted`, any number of times, 0 to 10 000 000. Compare key `(status = 'DeliveryStarted', delivery_fee_final_vnd = :previous_delivery_fee_vnd)`; zero rows updated is 409 `ORDER_STATE_CHANGED` with the current detail (this also answers an order that is already `Finished`: nothing can change after Finished, the database trigger refuses it too). Each correction inserts one row in `order_fee_correction` (account id and name snapshot, time, old fee, new fee) in the same transaction; the first fee entry is not a correction. Replay: zero rows, current fee equals the requested fee, and the latest correction row has the same account and `old = previous` returns 200 `Idempotent-Replay: true`. No `order_event` row is written (the record is the correction table, merged into the history by time). The customer sees only the latest fee.
12. Clarifications [v1.3 | 2026-11-02]: (a) the server owns the date window and returns it as `expected_date_range` (api/09); the client never uses the device clock for it. (b) The 409 on fee correction returns the full current order detail. (c) `FEE_UNCHANGED` (body-only check, new equals previous) is answered before the UPDATE and so before 409. (d) A fee sent on the status route for `DeliveryStarted` to `DeliveryStarted` is 422 `STATUS_TRANSITION_INVALID`. (e) "Shop today" comes from one injectable server clock in `Asia/Ho_Chi_Minh`, read once per request. (f) Migration 0008 as written is described in data-model/06 section 7; the sample seed changes in slice S2 or later.
11. Customer tracking reads these fields through a separate endpoint: ADR-0034.

## Old clients

Admin apps decode the status string; an unknown value (`Received`) breaks old builds. `APP_UPDATE_REQUIRED` is not defined (api/08 section 12). Customer apps never read the status and the `POST /v1/orders` contract does not change. Plan: ship backend, iOS and Android admin apps together; both admin apps are in limited distribution (ADR-0026), so the operator updates the few devices before the cutover. Query for forge-dev: apps must treat an unknown status as a neutral label, not a crash. [v1.1 | 2026-11-02] Hard cutover decision: no `APP_UPDATE_REQUIRED` is built. Reason: old builds cannot be given new behaviour after the fact, and the status field is the only break; backend, iOS and Android admin apps ship together and the few devices are updated before the cutover (ADR-0026). An old build that still connects shows its generic error state for unknown words; staff must update. New builds map unknown words to a neutral label and legacy event words per data-model/06 section 5. Revisit only if the operator cannot reach every device.

## Consequences

Positive: customer API untouched; capacity logic untouched. Negative: a hard cutover for admin apps; two fee fields to explain. Follow-up: concurrency tests (two date moves, move against start delivery), migration test with rows in every old status, test restore of the dump.

Rejected for the range: a CHECK on the table (depends on `now()`, not immutable, breaks restores) and a stored limit setting (the owner fixed 7 days; no setting asked).

## Sources

PostgreSQL READ COMMITTED re-checks the WHERE clause after a concurrent commit (https://www.postgresql.org/docs/current/transaction-iso.html, from memory, not fetched; medium confidence).
