# API Specification: order process, expected date, final fee

Part of [api.md](../api.md), section 10.13 (new). Version 1.2 [v1.2 | 2026-11-02]. Traces: FR-9, FR-13, FR-14, FR-16 to FR-19, FR-28 to FR-30, AC-26 to AC-29, AC-49 to AC-52; ADR-0033; order-process.md. Auth, rate limit, `no-store`: api/05. Status identifiers: `Received`, `Processing`, `DeliveryDateScheduled`, `DeliveryStarted`, `Finished`, `Cancelled`.

## 10.13.1 POST /v1/admin/orders/{order_code}/status (changed)

Body: `{ "expected_status", "to_status", "cancel_reason"?, "expected_delivery_date"?, "delivery_fee_vnd"? }` (ADR-0028 order of checks kept). Extra fields by target:

| `to_status` | Required | Refused if present |
| ----------- | -------- | ------------------ |
| Processing, Finished | none | all extras |
| DeliveryDateScheduled | `expected_delivery_date` (`YYYY-MM-DD`, shop today to today + 7 inclusive, Vietnam calendar) | reason, fee |
| DeliveryStarted | `delivery_fee_vnd` (integer 0 to 10 000 000) | reason, date |
| Cancelled | `cancel_reason` | date, fee |

Field codes in 422 `VALIDATION_FAILED` `fields[]` (api/08 11.1 style): `EXPECTED_DATE_REQUIRED`, `EXPECTED_DATE_INVALID` (not a date), `EXPECTED_DATE_PAST`, `EXPECTED_DATE_TOO_FAR` (after today + 7), `FEE_REQUIRED`, `FEE_INVALID` (not a whole number, below 0 or above 10 000 000), `FIELD_NOT_ALLOWED`. Pair not allowed (including cancel from DeliveryDateScheduled onward): 422 `STATUS_TRANSITION_INVALID`. Stale view: 409 `ORDER_STATE_CHANGED` with `details.order`. Replay: 200 `Idempotent-Replay: true`.

## 10.13.2 PUT /v1/admin/orders/{order_code}/expected-delivery-date (new, FR-28)

Body `{ "expected_status": "DeliveryDateScheduled", "previous_expected_delivery_date": "YYYY-MM-DD", "expected_delivery_date": "YYYY-MM-DD" }`. One transaction sets the actor settings and runs `UPDATE ... WHERE status = 'DeliveryDateScheduled' AND expected_delivery_date = :previous`, then inserts the change row. 200 with the order detail. Errors: 401/403; 404 `ORDER_NOT_FOUND`; 422 as above; 409 `ORDER_STATE_CHANGED` when status or stored date differs (detail returned; this also covers an order that already started delivery); replay per ADR-0033 Decision 2. The same date as stored by a stale view is 409; a no-op with a matching previous date is 422 `EXPECTED_DATE_UNCHANGED`. Range today to today + 7 inclusive checked on every move; `EXPECTED_DATE_PAST`, `EXPECTED_DATE_TOO_FAR`; a replay skips it. No daily-limit, lead or slot check.

## 10.13.3 Reads (changed)

`GET /v1/admin/orders`: `status` accepts `todo` (default, the four open steps), the six names, `all`; items add `expected_delivery_date` (null), `list_date`; `unfinished_count` per order-process.md section 4.

Date window [v1.2 | 2026-11-02]: the server owns "shop today". The order detail and every 409 `details.order` add `expected_date_range` `{ "min": "YYYY-MM-DD", "max": "YYYY-MM-DD" }` (shop today and today + 7, Vietnam calendar, computed at response time); the 422 `EXPECTED_DATE_PAST`/`EXPECTED_DATE_TOO_FAR` answers carry the same object in `details`. The client limits its picker to that object and never computes the window from the device clock; if the detail is older than the day, the server check still decides. "Shop today" is read once per request from an injectable server clock in `Asia/Ho_Chi_Minh` (no DST), the same function for range checks and list queries.

`GET /v1/admin/orders/{order_code}` adds: `requested_delivery_date` (the customer date, existing `delivery_date`), `expected_delivery_date`, `delivery_fee_estimate_vnd`, `delivery_fee_final_vnd` (null before entry), `items_subtotal_vnd`, `amount_to_collect_vnd` (null before entry), and `date_changes[]` (`old_date`, `new_date`, `changed_by_name`, `changed_at`, oldest first), `fee_corrections[]` (`old_fee_vnd`, `new_fee_vnd`, `changed_by_name`, `changed_at`, oldest first) [v1.1 | 2026-11-02].

Customer endpoints: unchanged (no status shown; `POST /v1/orders` still checks `expected_total_vnd` = cakes + estimate). Push: unchanged (new-order push only).

## 10.13.6 PUT /v1/admin/orders/{order_code}/delivery-fee (new, FR-30) [v1.1 | 2026-11-02]

Owner and staff. Body `{ "expected_status": "DeliveryStarted", "previous_delivery_fee_vnd": 25000, "delivery_fee_vnd": 30000 }`, all three required, integers except the status. One transaction sets the actor settings, runs `UPDATE ... WHERE status = 'DeliveryStarted' AND delivery_fee_final_vnd = :previous`, inserts the `order_fee_correction` row. 200 with the order detail (`amount_to_collect_vnd` follows the new fee).

| Case | Answer |
| ---- | ------ |
| `expected_status` is not `DeliveryStarted` | 422 `FEE_CORRECTION_NOT_ALLOWED`, no write |
| Missing or wrong type field | 422 `VALIDATION_FAILED`: `FEE_REQUIRED`, `PREVIOUS_FEE_REQUIRED`, `FEE_INVALID` (not whole, below 0, above 10 000 000) |
| New fee equals `previous` (body only, no database read) | 422 `FEE_UNCHANGED`, decided after the range check and before the UPDATE, so it wins over 409 [v1.2 | 2026-11-02] |
| Status is no longer `DeliveryStarted` (including `Finished`, `Cancelled`) or stored fee differs from `previous` | 409 `ORDER_STATE_CHANGED`; `details.order` is the full order detail (10.13.3) with `status`, `delivery_fee_final_vnd`, `amount_to_collect_vnd`, so the client shows the current fee from the answer without a second read [v1.2 | 2026-11-02] |
| Replay (ADR-0033 Decision 10) | 200 `Idempotent-Replay: true` |
| 401, 403, 404 `ORDER_NOT_FOUND`, 429 | as api/05 |

Check order [v1.2 | 2026-11-02]: session, role, body fields, `expected_status`, range, `FEE_UNCHANGED`, UPDATE (409 or replay). A fee sent through the status route (10.13.1) as `DeliveryStarted` to `DeliveryStarted` is not a pair: 422 `STATUS_TRANSITION_INVALID`, no write; only this route corrects a fee.

A second staff correcting from a stale view gets 409 and must re-read; no overwrite. Fixtures: `order-detail-fee-corrected.json` (two `fee_corrections`), `error-validation-fee-invalid.json`, `error-fee-correction-not-allowed.json`, `error-order-state-changed-fee.json`, `error-validation-expected-date-too-far.json`.

## 10.13.4 Fixtures to add in `contracts/fixtures/admin/` (forge-dev, outside atlas paths)

`order-detail-received.json`, `order-detail-delivery-date-scheduled.json` (with two `date_changes`), `order-detail-delivery-started.json` (fee 25 000, to collect), `order-detail-delivery-started-free.json` (fee 0), `error-status-transition-invalid-cancel.json`, `error-validation-expected-date-past.json`, `error-validation-fee-required.json`, `error-order-state-changed-date.json`; update every existing status example from `New`/`Confirmed`/`Completed`.

## 10.13.5 Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.2 | 2026-11-02 | 409 body, `expected_date_range` (server owns the window), FEE_UNCHANGED order, status-route fee refusal, clock source. |
| 1.1 | 2026-11-02 | Date range today to today + 7 (`EXPECTED_DATE_TOO_FAR`); fee correction endpoint 10.13.6 and `fee_corrections[]`. |
| 1.0 | 2026-11-02 | First version. |
