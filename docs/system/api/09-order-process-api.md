# API Specification: order process, expected date, final fee

Part of [api.md](../api.md), section 10.13 (new). Version 1.0 [v1.0 | 2026-11-02]. Traces: FR-9, FR-13, FR-14, FR-16 to FR-19, FR-28, FR-29, AC-26 to AC-29, AC-49 to AC-52; ADR-0033; order-process.md. Auth, rate limit, `no-store`: api/05. Status identifiers: `Received`, `Processing`, `DeliveryDateScheduled`, `DeliveryStarted`, `Finished`, `Cancelled`.

## 10.13.1 POST /v1/admin/orders/{order_code}/status (changed)

Body: `{ "expected_status", "to_status", "cancel_reason"?, "expected_delivery_date"?, "delivery_fee_vnd"? }` (ADR-0028 order of checks kept). Extra fields by target:

| `to_status` | Required | Refused if present |
| ----------- | -------- | ------------------ |
| Processing, Finished | none | all extras |
| DeliveryDateScheduled | `expected_delivery_date` (`YYYY-MM-DD`, not before shop today) | reason, fee |
| DeliveryStarted | `delivery_fee_vnd` (integer 0 to 10 000 000) | reason, date |
| Cancelled | `cancel_reason` | date, fee |

Field codes in 422 `VALIDATION_FAILED` `fields[]` (api/08 11.1 style): `EXPECTED_DATE_REQUIRED`, `EXPECTED_DATE_INVALID` (not a date), `EXPECTED_DATE_PAST`, `FEE_REQUIRED`, `FEE_INVALID` (not a whole number, below 0 or above 10 000 000), `FIELD_NOT_ALLOWED`. Pair not allowed (including cancel from DeliveryDateScheduled onward): 422 `STATUS_TRANSITION_INVALID`. Stale view: 409 `ORDER_STATE_CHANGED` with `details.order`. Replay: 200 `Idempotent-Replay: true`.

## 10.13.2 PUT /v1/admin/orders/{order_code}/expected-delivery-date (new, FR-28)

Body `{ "expected_status": "DeliveryDateScheduled", "previous_expected_delivery_date": "YYYY-MM-DD", "expected_delivery_date": "YYYY-MM-DD" }`. One transaction sets the actor settings and runs `UPDATE ... WHERE status = 'DeliveryDateScheduled' AND expected_delivery_date = :previous`, then inserts the change row. 200 with the order detail. Errors: 401/403; 404 `ORDER_NOT_FOUND`; 422 as above; 409 `ORDER_STATE_CHANGED` when status or stored date differs (detail returned; this also covers an order that already started delivery); replay per ADR-0033 Decision 2. The same date as stored by a stale view is 409; a no-op with a matching previous date is 422 `EXPECTED_DATE_UNCHANGED`. No daily-limit, lead or slot check.

## 10.13.3 Reads (changed)

`GET /v1/admin/orders`: `status` accepts `todo` (default, the four open steps), the six names, `all`; items add `expected_delivery_date` (null), `list_date`; `unfinished_count` per order-process.md section 4.

`GET /v1/admin/orders/{order_code}` adds: `requested_delivery_date` (the customer date, existing `delivery_date`), `expected_delivery_date`, `delivery_fee_estimate_vnd`, `delivery_fee_final_vnd` (null before entry), `items_subtotal_vnd`, `amount_to_collect_vnd` (null before entry), and `date_changes[]` (`old_date`, `new_date`, `changed_by_name`, `changed_at`, oldest first).

Customer endpoints: unchanged (no status shown; `POST /v1/orders` still checks `expected_total_vnd` = cakes + estimate). Push: unchanged (new-order push only).

## 10.13.4 Fixtures to add in `contracts/fixtures/admin/` (forge-dev, outside atlas paths)

`order-detail-received.json`, `order-detail-delivery-date-scheduled.json` (with two `date_changes`), `order-detail-delivery-started.json` (fee 25 000, to collect), `order-detail-delivery-started-free.json` (fee 0), `error-status-transition-invalid-cancel.json`, `error-validation-expected-date-past.json`, `error-validation-fee-required.json`, `error-order-state-changed-date.json`; update every existing status example from `New`/`Confirmed`/`Completed`.

## 10.13.5 Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-11-02 | First version. |
