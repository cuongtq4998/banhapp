# API Specification: Admin session, sign out other phones, push token, orders

Part of [api.md](../api.md) (index, version, change log), sections 10.6 to 10.12. Aligned with built slices B2 and B3 in v1.18 [v1.18 | 2026-11-01]; `me` gained `email` in v1.22 [v1.22 | 2026-11-01]; push token and payload aligned with slice B7 in v1.21 [v1.21 | 2026-11-01]. New in v1.13 [v1.13 | 2026-10-31]; Unfinished view and push token columns in v1.15 [v1.15 | 2026-10-31]; simplified in v1.16: device list, Unfinished view, filters and history removed, sign out other phones added [v1.16 | 2026-10-31]. Auth: Bearer access token, roles owner and staff unless stated (api/05 section 9). All responses `no-store`.

### 10.6 GET /v1/admin/me, DELETE /v1/admin/session, DELETE /v1/admin/sessions/others

`GET /v1/admin/me` returns `{ "account": { "name", "role" }, "email", "device_id", "server_date" }`. `email` is the signed-in person's own address, read from `account` for the calling session only (never another account's); it is never logged, the answer is `no-store` like every admin response, and the apps keep it in memory only [v1.22 | 2026-11-01]. The apps need it after a launch with a stored session, where the sign-in answer is no longer at hand (S-A13 shows it). `DELETE /v1/admin/session` revokes the calling phone (`signed_out`), deletes its push token, answers 204; repeating it answers 401. A sign-out made offline is repeated by the app later (refresh, then this call) until 204 or 401; until then the server session lives and its push token may still receive pushes (ADR-0022, TQ-D6, R-30). FR-2.

`DELETE /v1/admin/sessions/others` (FR-4, ADR-0022 v1.3) revokes every other unrevoked session of the calling account (`signed_out_others`), clears their push tokens and writes one `security_event`, in one transaction; the calling phone stays signed in. Response 204, also when there is no other session (a repeat is harmless). The other phones fail their next request with 401 `SESSION_REVOKED` at once (the access token is checked against the session row) and cannot renew; "within 5 minutes" in BR-5 is the upper bound. Any signed-in role, own account only: there is no way to name another account or phone. Errors: 401, 429 `RATE_LIMITED`. No request body. [v1.16 | 2026-10-31]

### 10.7 (removed) [v1.16 | 2026-10-31]

The device list and per-device revoke (`GET /v1/admin/devices`, `DELETE /v1/admin/devices/{device_id}`) and the error `DEVICE_NOT_FOUND` are gone (P-2). Number kept so references stay valid.

### 10.8 PUT /v1/admin/push-token (built in slice B7 [v1.21 | 2026-11-01])

`PUT` body `{ "platform": "ios"|"android", "token": string (1 to 512), "apns_environment": "production"|"sandbox" (required for ios; ignored and not stored for android) }`; 204 without body. Opened with `adminGroup()` (owner and staff). Writes `device_session.push_token` and `push_apns_environment` of the calling session and, in the same transaction, clears both on any other session that holds the same token, so one token has one owner. A repeat with the same values is 204. Errors: 401 as for any admin route; 422 `VALIDATION_FAILED` with one entry in `fields[]` (the first bad field only, checked in this order) [v1.21 | 2026-11-01]:

| Field | Code | When |
| ----- | ---- | ---- |
| (key) | `UNKNOWN_FIELD` | A key other than `platform`, `token`, `apns_environment` |
| `platform` | `PLATFORM_INVALID` | Missing, not a string, or not `ios` or `android` |
| `token` | `TOKEN_INVALID` | Missing, not a string, empty, over 512 characters, or holds a space or a control character |
| `apns_environment` | `APNS_ENVIRONMENT_INVALID` | Not `production` or `sandbox`; also missing or null when `platform` is `ios` |
| `platform` | `PLATFORM_MISMATCH` | The body platform differs from the platform the phone signed in with (`device_session.platform`) |

A body that is not a JSON object is 422 `VALIDATION_FAILED` without `fields[]`. Rate limit: shared. FR-25 (the app does not call `PUT` when the phone's permission is denied). There is no `DELETE`: sign-out, sign-out of other phones, refresh reuse and deactivation clear the token and its environment on the server (`DELETE /v1/admin/push-token` was removed in v1.16) [v1.16 | 2026-10-31]. The sender is off, recording or live (`PUSH_PROVIDER`, deployment/04); the route works in every mode.

### 10.9 GET /v1/admin/orders

| Query | Type | Rules |
| ----- | ---- | ----- |
| status | string | One of `todo` (the four open steps Received, Processing, DeliveryDateScheduled, DeliveryStarted; the default when absent), `Received`, `Processing`, `DeliveryDateScheduled`, `DeliveryStarted`, `Finished`, `Cancelled`, `all` [v1.24 | 2026-11-02]; the old words New, Confirmed, Completed are refused as `STATUS_INVALID` (BR-9, FR-10) |
| date_preset | string | `today` or `tomorrow` (shop date on the server). Excludes `delivery_date` |
| delivery_date | date | One delivery date (FR-10) |
| q | string | 3 to 50 characters after trimming (counted after Unicode NFC normalisation); order code with or without `BT-`, part of the name, part of the phone; no control characters (a NUL or other control character is rejected); a text made only of digits, spaces and `+-().` is also read as a phone number and needs at least 3 digits; matching is "contains", ignoring case and accents (ADR-0029 v1.5, BR-10) [v1.18 | 2026-11-01] |
| cursor | string | Opaque, from `next_cursor`; the client never builds or reads it, and the encoding is not part of the contract. Anything that the server did not issue answers `CURSOR_INVALID` [v1.18 | 2026-11-01] |

Unknown and repeated parameters are rejected as `VALIDATION_FAILED`; every defect is listed in `fields[]` with the codes of api/08 section 11.1 [v1.18 | 2026-11-01]. Window (BR-9, ADR-0029 v1.3), whatever the filters: New and Confirmed orders of any age, and Completed or Cancelled orders placed in the last 90 days. Sort: `delivery_date`, slot start, `created_at`, id, ascending (BR-9); these keys never change, so pages do not repeat rows; new and status-changed orders appear on the next refresh from page 1 (ADR-0029, R-14) [v1.14 | 2026-10-31]. 200 response:

| Field | Type | Notes |
| ----- | ---- | ----- |
| items | array (at most 50) | `order_code`, `status`, `customer_name`, `delivery_date`, `slot` (`start`, `end`), `total_cakes`, `total_vnd`, `district_name`, `created_at` |
| next_cursor | string or null | Null at the end; no row repeats between pages |
| unfinished_count | integer | Badge: an open step (see `status=todo`) with `COALESCE(expected_delivery_date, delivery_date) <= server_date` [v1.24 | 2026-11-02] (order-process.md section 4), whatever the filters; the app shows 99+ above 99 (FR-13) [v1.16 | 2026-10-31] |
| server_date | date | Shop date; the app computes "due today" and "overdue N days" with it (FR-9) |

Errors: 401, 422 `VALIDATION_FAILED` (`fields[].field` names the parameter; `date_from`, `date_to` and `view` are unknown parameters, a repeated parameter is `REPEATED_PARAMETER`), 429 (the shared per-address read budget of api/01 counts `GET /v1/admin/orders` and the detail; the status `POST` has no rate limit of its own), 503 [v1.18 | 2026-11-01]. Side effects: none. Review accounts see only `is_demo` rows. Example: `GET /v1/admin/orders?status=New&date_preset=today` returns `{ "items": [ { "order_code": "BT-7K3M9Q", "status": "New", "customer_name": "Tran Thi B", "delivery_date": "2026-11-02", "slot": { "start": "08:00", "end": "10:00" }, "total_cakes": 2, "total_vnd": 120000, "district_name": "Quan An Phu", "created_at": "2026-10-31T03:15:09Z" } ], "next_cursor": null, "unfinished_count": 1, "server_date": "2026-11-02" }`.

### 10.10 GET /v1/admin/orders/{order_code}

`order_code` matches `^BT-[2-9A-HJKMNP-Z]{6}$` (else 404). 200: the summary fields of 10.9 plus `customer_phone` (E.164), `customer_address`, `note`, `items` (`product_name`, `quantity`, `unit_price_vnd`, `line_total_vnd`; stored values, sorted by `product_name` then product id, FR-14), `items_subtotal_vnd`, `delivery_fee_vnd`, `cancel_reason` (or null), `allowed_actions` (a subset of `process`, `schedule_delivery`, `start_delivery`, `finish`, `cancel`, `change_date`, `correct_fee`, computed from the status, empty for final states; defined in api/09 10.13.7) [v1.27 | 2026-11-02], and `last_change` `{ "actor_name", "at" }` for the line "last changed by <name>, <time>" (FR-14; the name is null when the customer placed the order and nobody changed it). The full status history is recorded (BR-3) but not returned; the date changes are returned as `date_changes[]` and the new detail fields (`requested_delivery_date`, `expected_delivery_date`, `delivery_fee_estimate_vnd`, `delivery_fee_final_vnd`, `amount_to_collect_vnd`) are in api/09 10.13.3; `allowed_actions` follows the six-step table of order-process.md section 2 [v1.24 | 2026-11-02]. The window function of ADR-0029 v1.3 applies: an open order of any age is returned; a Finished or Cancelled order only within 90 days of being placed. A code that does not exist, a finished order placed more than 90 days ago and (for review accounts) a non-demo order all answer 404 `ORDER_NOT_FOUND`. This route is what a push tap calls (FR-26). The response is personal data: never logged. FR-14, BR-9.

### 10.11 POST /v1/admin/orders/{order_code}/status

Request: `expected_status` (the status the client shows), `to_status`, `cancel_reason` (required when `to_status` is `Cancelled`, one of `customer_asked`, `cannot_deliver`, `cannot_reach_customer`, `fake_spam`; forbidden otherwise; `day_full` removed [v1.16 | 2026-10-31]). Allowed pairs: New to Confirmed, New to Cancelled, Confirmed to Completed, Confirmed to Cancelled. Checks and transaction: ADR-0028. Responses:

| Status | Code | Body |
| ------ | ---- | ---- |
| 200 | | The order detail of 10.10 after the change; header `Idempotent-Replay: true` when the repeat rule of ADR-0028 applied |
| 404 | `ORDER_NOT_FOUND` | Unknown, malformed code, or outside the window and not a replay. Specified: an exact repeat of the change that closed an order which has since left the window answers 200 with `Idempotent-Replay: true` (FR-19, ADR-0028 v1.3). Built as specified since B6: the repeat answers 200 (defect D-1 fixed, architecture/13 section 29.2); any other call on such an order is 404 [v1.20 | 2026-11-01] |
| 409 | `ORDER_STATE_CHANGED` | `details.order` is the current detail of 10.10; the client shows the current status (FR-19) |
| 422 | `STATUS_TRANSITION_INVALID` | The pair is not allowed (for example New to Completed, or from a final state); `details.status` is `expected_status` |
| 422 | `CANCEL_REASON_REQUIRED` | Cancelled without a valid reason |
| 422 | `VALIDATION_FAILED` | Field codes in `fields[]`: `UNKNOWN_FIELD` (a key other than the three), `STATUS_INVALID` (`expected_status` or `to_status` missing, not a string or not one of the four statuses), `REASON_NOT_ALLOWED` (`cancel_reason` sent with a target other than `Cancelled`; `null` is accepted and ignored). A body that is not a JSON object is `VALIDATION_FAILED` without fields [v1.18 | 2026-11-01] |

Side effects (one transaction): status and `cancel_reason` set; `order_event` with actor (`owner` or `staff`), actor name and reason; on cancel `day_load` of the order's date reduced by `total_cakes` (trigger, BR-2; no floor, a date without a row is left alone: data-model/05 section 11) [v1.18 | 2026-11-01]. If the `day_load` row holds fewer cakes than the order (only after manual SQL) the cancel changes nothing and answers 500 `INTERNAL_ERROR` with `details.reason = DAY_LOAD_INCONSISTENT`; the log line is "Request failed" with the reason only [v1.23 | 2026-11-01]. Demo orders never touch `day_load`. No notification to the customer. Idempotency: ADR-0028. Example request `{ "expected_status": "New", "to_status": "Cancelled", "cancel_reason": "customer_asked" }`; example 409 body `{ "error": { "code": "ORDER_STATE_CHANGED", "message_key": "ERR_ORDER_STATE_CHANGED", "details": { "order": { "order_code": "BT-7K3M9Q", "status": "Confirmed" } } }, "request_id": "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0002" }` (order shortened).

### 10.12 Push notification payload (for the clients)

Not an endpoint. APNs alert `title-loc-key` `PUSH_NEW_ORDER_TITLE`, `loc-key` `PUSH_NEW_ORDER_BODY`, `loc-args` `[order_code, cakes, "dd/MM/yyyy"]`; custom field `order_code`; FCM HTTP v1 `message.android.notification.title_loc_key`, `body_loc_key`, `body_loc_args` (same three values) and `message.data.order_code` [v1.21 | 2026-11-01]; Android channel id `new_orders`. The payload holds only the order code, the cake count and the delivery date as `dd/MM/yyyy`; no name, phone, address, note (FR-26) [v1.21 | 2026-11-01]. The same alert settings go to both services: priority high, expiry 3,600 s, APNs thread id `new_orders`. Delivery settings (importance, priority, expiry one hour, interruption level): ADR-0024 v1.1 [v1.14 | 2026-10-31]. Tap opens `GET /v1/admin/orders/{order_code}` after sign-in if needed (FR-26).
