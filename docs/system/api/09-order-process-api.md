# API Specification: order process, expected date, final fee

Part of [api.md](../api.md), section 10.13 (new). Version 1.5 [v1.5 | 2026-11-02]. Traces: FR-9, FR-13, FR-14, FR-16 to FR-19, FR-28 to FR-30, AC-26 to AC-29, AC-49 to AC-52; ADR-0033; order-process.md. Auth, rate limit, `no-store`: api/05. Status identifiers: `Received`, `Processing`, `DeliveryDateScheduled`, `DeliveryStarted`, `Finished`, `Cancelled`.

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

Body `{ "expected_status": "DeliveryDateScheduled", "previous_expected_delivery_date": "YYYY-MM-DD", "expected_delivery_date": "YYYY-MM-DD" }`. One transaction sets the actor settings and runs `UPDATE ... WHERE status = 'DeliveryDateScheduled' AND expected_delivery_date = :previous`, then inserts the change row. 200 with the order detail. Errors: 401/403; 404 `ORDER_NOT_FOUND`; 422 as above; 409 `ORDER_STATE_CHANGED` when status or stored date differs (detail returned; this also covers an order that already started delivery); replay per ADR-0033 Decision 2. The same date as stored by a stale view is 409; a no-op with a matching previous date is 422 `EXPECTED_DATE_UNCHANGED`.

Check order [v1.28 | 2026-11-02] (same shape as the fee route, 10.13.6): session, role, body fields (unknown key `UNKNOWN_FIELD`; `previous_expected_delivery_date` then `expected_delivery_date`: `EXPECTED_DATE_REQUIRED`, `EXPECTED_DATE_INVALID`, each reported on its own key), `expected_status`, range (`EXPECTED_DATE_PAST`, `EXPECTED_DATE_TOO_FAR`, new date only), `EXPECTED_DATE_UNCHANGED` (body only, before the UPDATE, so it wins over 409), UPDATE (409 or replay). `expected_status` missing, not a string, or any value other than `DeliveryDateScheduled` is 422 `VALIDATION_FAILED`, field `expected_status`, code `STATUS_INVALID`, no write: a wrong value is a client defect, not a stale view; staleness is only the 409 of the UPDATE. Unlike the fee route there is no separate error code for it (10.13.6 keeps `FEE_CORRECTION_NOT_ALLOWED`, built).

Unknown keys in both correction bodies are 422 `VALIDATION_FAILED`, field = the key, code `UNKNOWN_FIELD` (the canonical name, api/08 11.1); `FIELD_NOT_ALLOWED` is another code (a known key refused for this target, 10.13.1) and `FIELD_UNKNOWN` is the older name of the built owner and customer routes (api/04, api/07), kept there and not used by any admin order or device route. Range today to today + 7 inclusive checked on every move; `EXPECTED_DATE_PAST`, `EXPECTED_DATE_TOO_FAR`; a replay skips it. No daily-limit, lead or slot check.

## 10.13.3 Reads (changed)

`GET /v1/admin/orders`: `status` accepts `todo` (default, the four open steps), the six names, `all`; items add `expected_delivery_date` (`YYYY-MM-DD` or null) and `list_date` (`YYYY-MM-DD`, never null: `COALESCE(expected_delivery_date, delivery_date)`), next to the existing `delivery_date` (the requested date) [v1.4 | 2026-11-02]. Sort, cursor, the red mark (`list_date <= server_date` on an open item) and `unfinished_count` all use `list_date` (order-process.md section 4); the apps refresh from page 1 after any status or date change.

Date window [v1.2 | 2026-11-02]: the server owns "shop today". The order detail and every 409 `details.order` add `expected_date_range` `{ "min": "YYYY-MM-DD", "max": "YYYY-MM-DD" }` (shop today and today + 7, Vietnam calendar, computed at response time); the 422 `EXPECTED_DATE_PAST`/`EXPECTED_DATE_TOO_FAR` answers carry the same object in `details`. The client limits its picker to that object and never computes the window from the device clock; if the detail is older than the day, the server check still decides. "Shop today" is read once per request from an injectable server clock in `Asia/Ho_Chi_Minh` (no DST), the same function for range checks and list queries.

`GET /v1/admin/orders/{order_code}` adds: `requested_delivery_date` (the customer date, existing `delivery_date`), `expected_delivery_date`, `delivery_fee_estimate_vnd`, `delivery_fee_final_vnd` (null before entry), `items_subtotal_vnd`, `amount_to_collect_vnd` (null before entry), and `date_changes[]` (`old_date`, `new_date`, `changed_by_name`, `changed_at`, oldest first), `fee_corrections[]` (`old_fee_vnd`, `new_fee_vnd`, `changed_by_name`, `changed_at`, oldest first) [v1.1 | 2026-11-02].

Last change and fee history [v1.4 | 2026-11-02]: `last_change` is `{ "actor_name", "at", "kind" }` where `kind` is `status`, `date` or `fee`, the latest of `order_event`, `order_expected_date_change` and `order_fee_correction` (order-process.md 4.2). Ties on `at`: `status`, then `date`, then `fee`, then the larger row id. `actor_name` is null only when the latest record is the customer's `created` event. `delivery_fee_entry` is `{ "entered_by_name", "entered_at" }` or null before the entry (and for backfilled legacy rows): the actor and time of the DeliveryDateScheduled to DeliveryStarted event. Fee history in the detail is that entry first, then `fee_corrections[]` oldest first; no new column. No merged status, date and fee history is returned (no field, no union query) [v1.5 | 2026-11-02]: `design/admin-orders/12` shows each record list on its own and the last change line only.

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

## 10.13.7 `allowed_actions` and the action to endpoint map [v1.3 | 2026-11-02]

Computed from the status for owner and staff alike (the same roles as every status change, api/05); `Finished` and `Cancelled` get `[]`. Names are API identifiers; the order of the array is the table order. The UI bar (design/admin-orders/12, 5.12) shows exactly these: left action, right action.

| Status | `allowed_actions` | Action | Endpoint and body |
| ------ | ----------------- | ------ | ----------------- |
| Received | `cancel`, `process` | `process` | POST status `{expected_status:"Received", to_status:"Processing"}` |
| Processing | `cancel`, `schedule_delivery` | `schedule_delivery` | POST status `to_status:"DeliveryDateScheduled"`, `expected_delivery_date` |
| DeliveryDateScheduled | `change_date`, `start_delivery` | `start_delivery` | POST status `to_status:"DeliveryStarted"`, `delivery_fee_vnd` |
| DeliveryStarted | `correct_fee`, `finish` | `finish` | POST status `to_status:"Finished"` |
| Received, Processing | (see above) | `cancel` | POST status `to_status:"Cancelled"`, `cancel_reason` |
| DeliveryDateScheduled | | `change_date` | PUT `/expected-delivery-date` (10.13.2) |
| DeliveryStarted | | `correct_fee` | PUT `/delivery-fee` (10.13.6) |

`to_status` to transition: Processing = `process`, DeliveryDateScheduled = `schedule_delivery`, DeliveryStarted = `start_delivery`, Finished = `finish`, Cancelled = `cancel`. The old names `confirm` and `complete` are gone. An action not in the list is refused as in the sections above. Replays and repeats: order-process.md 4.1.

## 10.13.4 Fixtures to add in `contracts/fixtures/admin/` (forge-dev, outside atlas paths)

`order-detail-received.json`, `order-detail-delivery-date-scheduled.json` (with two `date_changes`), `order-detail-delivery-started.json` (fee 25 000, to collect), `order-detail-delivery-started-free.json` (fee 0), `error-status-transition-invalid-cancel.json`, `error-validation-expected-date-past.json`, `error-validation-fee-required.json`, `error-order-state-changed-date.json`; update every existing status example from `New`/`Confirmed`/`Completed`.

## 10.13.5 Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.5 | 2026-11-02 | Date route check order and `STATUS_INVALID`; canonical `UNKNOWN_FIELD`; no merged history; list filters match `list_date`. |
| 1.4 | 2026-11-02 | List item `list_date` rule; `last_change.kind` from three records; `delivery_fee_entry`. |
| 1.3 | 2026-11-02 | Section 10.13.7: `allowed_actions` vocabulary, action to endpoint map, `to_status` to action. |
| 1.2 | 2026-11-02 | 409 body, `expected_date_range` (server owns the window), FEE_UNCHANGED order, status-route fee refusal, clock source. |
| 1.1 | 2026-11-02 | Date range today to today + 7 (`EXPECTED_DATE_TOO_FAR`); fee correction endpoint 10.13.6 and `fee_corrections[]`. |
| 1.0 | 2026-11-02 | First version. |
