# API Specification: Admin session, sign out other phones, push token, orders

Part of [api.md](../api.md) (index, version, change log), sections 10.6 to 10.12. New in v1.13 [v1.13 | 2026-10-31]; Unfinished view and push token columns in v1.15 [v1.15 | 2026-10-31]; simplified in v1.16: device list, Unfinished view, filters and history removed, sign out other phones added [v1.16 | 2026-10-31]. Auth: Bearer access token, roles owner and staff unless stated (api/05 section 9). All responses `no-store`.

### 10.6 GET /v1/admin/me, DELETE /v1/admin/session, DELETE /v1/admin/sessions/others

`GET /v1/admin/me` returns `{ "account": { "name", "role" }, "device_id", "server_date" }`. `DELETE /v1/admin/session` revokes the calling phone (`signed_out`), deletes its push token, answers 204; repeating it answers 401. A sign-out made offline is repeated by the app later (refresh, then this call) until 204 or 401; until then the server session lives and its push token may still receive pushes (ADR-0022, TQ-D6, R-30). FR-2.

`DELETE /v1/admin/sessions/others` (FR-4, ADR-0022 v1.3) revokes every other unrevoked session of the calling account (`signed_out_others`), clears their push tokens and writes one `security_event`, in one transaction; the calling phone stays signed in. Response 204, also when there is no other session (a repeat is harmless). The other phones fail their next request with 401 `SESSION_REVOKED` at once (the access token is checked against the session row) and cannot renew; "within 5 minutes" in BR-5 is the upper bound. Any signed-in role, own account only: there is no way to name another account or phone. Errors: 401, 429 `RATE_LIMITED`. No request body. [v1.16 | 2026-10-31]

### 10.7 (removed) [v1.16 | 2026-10-31]

The device list and per-device revoke (`GET /v1/admin/devices`, `DELETE /v1/admin/devices/{device_id}`) and the error `DEVICE_NOT_FOUND` are gone (P-2). Number kept so references stay valid.

### 10.8 PUT /v1/admin/push-token

`PUT` body `{ "platform": "ios"|"android", "token": string (1 to 512), "apns_environment": "production"|"sandbox" (required for ios) }`; 204. Writes `device_session.push_token` of the calling phone and moves a token seen on another session to this one. Errors: 422 `VALIDATION_FAILED`. Rate limit: shared. FR-25 (the app does not call `PUT` when the phone's permission is denied). `DELETE /v1/admin/push-token` was removed in v1.16: sign-out, sign-out of other phones and deactivation clear the token on the server [v1.16 | 2026-10-31].

### 10.9 GET /v1/admin/orders

| Query | Type | Rules |
| ----- | ---- | ----- |
| status | string | One of `todo` (New and Confirmed, the default when absent), `New`, `Confirmed`, `Completed`, `Cancelled`, `all` (BR-9, FR-10) |
| date_preset | string | `today` or `tomorrow` (shop date on the server). Excludes `delivery_date` |
| delivery_date | date | One delivery date (FR-10) |
| q | string | 2 to 50 characters; order code, part of the name, part of the phone (ADR-0029, BR-10) |
| cursor | string | Opaque, from `next_cursor` |

Unknown parameters are rejected as `VALIDATION_FAILED`. Window (BR-9, ADR-0029 v1.3), whatever the filters: New and Confirmed orders of any age, and Completed or Cancelled orders placed in the last 90 days. Sort: `delivery_date`, slot start, `created_at`, id, ascending (BR-9); these keys never change, so pages do not repeat rows; new and status-changed orders appear on the next refresh from page 1 (ADR-0029, R-14) [v1.14 | 2026-10-31]. 200 response:

| Field | Type | Notes |
| ----- | ---- | ----- |
| items | array (at most 50) | `order_code`, `status`, `customer_name`, `delivery_date`, `slot` (`start`, `end`), `total_cakes`, `total_vnd`, `district_name`, `created_at` |
| next_cursor | string or null | Null at the end; no row repeats between pages |
| unfinished_count | integer | Badge: New or Confirmed with `delivery_date <= server_date`, whatever the filters; the app shows 99+ above 99 (FR-13) [v1.16 | 2026-10-31] |
| server_date | date | Shop date; the app computes "due today" and "overdue N days" with it (FR-9) |

Errors: 401, 422 `VALIDATION_FAILED` (`fields` name the parameter; repeated `status`, `date_from`, `date_to` and `view` are unknown parameters), 429, 503. Side effects: none. Review accounts see only `is_demo` rows. Example: `GET /v1/admin/orders?status=New&date_preset=today` returns `{ "items": [ { "order_code": "BT-7K3M9Q", "status": "New", "customer_name": "Tran Thi B", "delivery_date": "2026-11-02", "slot": { "start": "08:00", "end": "10:00" }, "total_cakes": 2, "total_vnd": 120000, "district_name": "Quan An Phu", "created_at": "2026-10-31T03:15:09Z" } ], "next_cursor": null, "unfinished_count": 1, "server_date": "2026-11-02" }`.

### 10.10 GET /v1/admin/orders/{order_code}

`order_code` matches `^BT-[2-9A-HJKMNP-Z]{6}$` (else 404). 200: the summary fields of 10.9 plus `customer_phone` (E.164), `customer_address`, `note`, `items` (`product_name`, `quantity`, `unit_price_vnd`, `line_total_vnd`; stored values, FR-14), `items_subtotal_vnd`, `delivery_fee_vnd`, `cancel_reason` (or null), `allowed_actions` (subset of `confirm`, `complete`, `cancel`, computed from the status; empty for final states), and `last_change` `{ "actor_name", "at" }` for the line "last changed by <name>, <time>" (FR-14; the name is null when the customer placed the order and nobody changed it). The full history is recorded (BR-3) but not returned [v1.16 | 2026-10-31]. The window function of ADR-0029 v1.3 applies: an open order of any age is returned; a Completed or Cancelled order only within 90 days of being placed. A code that does not exist, a finished order placed more than 90 days ago and (for review accounts) a non-demo order all answer 404 `ORDER_NOT_FOUND`. This route is what a push tap calls (FR-26). The response is personal data: never logged. FR-14, BR-9.

### 10.11 POST /v1/admin/orders/{order_code}/status

Request: `expected_status` (the status the client shows), `to_status`, `cancel_reason` (required when `to_status` is `Cancelled`, one of `customer_asked`, `cannot_deliver`, `cannot_reach_customer`, `fake_spam`; forbidden otherwise; `day_full` removed [v1.16 | 2026-10-31]). Allowed pairs: New to Confirmed, New to Cancelled, Confirmed to Completed, Confirmed to Cancelled. Checks and transaction: ADR-0028. Responses:

| Status | Code | Body |
| ------ | ---- | ---- |
| 200 | | The order detail of 10.10 after the change; header `Idempotent-Replay: true` when the repeat rule of ADR-0028 applied |
| 404 | `ORDER_NOT_FOUND` | Unknown or outside the window (the window of 10.10 applies; the reply of a change that moves an old order out of the window is still built in the same transaction, a later repeat answers 404 and the app refreshes, ADR-0028) |
| 409 | `ORDER_STATE_CHANGED` | `details.order` is the current detail of 10.10; the client shows the current status (FR-19) |
| 422 | `STATUS_TRANSITION_INVALID` | The pair is not allowed (for example New to Completed, or from a final state); `details.status` is `expected_status` |
| 422 | `CANCEL_REASON_REQUIRED` | Cancelled without a valid reason |
| 422 | `VALIDATION_FAILED` | Unknown field, bad enum, reason with a non-cancel target |

Side effects (one transaction): status and `cancel_reason` set; `order_event` with actor, actor name and reason; on cancel `day_load` reduced by `total_cakes` (trigger, BR-2). No notification to the customer. Idempotency: ADR-0028. Example request `{ "expected_status": "New", "to_status": "Cancelled", "cancel_reason": "customer_asked" }`; example 409 body `{ "error": { "code": "ORDER_STATE_CHANGED", "message_key": "ERR_ORDER_STATE_CHANGED", "details": { "order": { "order_code": "BT-7K3M9Q", "status": "Confirmed" } } }, "request_id": "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0002" }` (order shortened).

### 10.12 Push notification payload (for the clients)

Not an endpoint. APNs alert `title-loc-key` `PUSH_NEW_ORDER_TITLE`, `loc-key` `PUSH_NEW_ORDER_BODY`, `loc-args` `[order_code, cakes, "dd/MM/yyyy"]`; custom field `order_code`; FCM `notification.title_loc_key`, `body_loc_key`, `body_loc_args` and `data.order_code`; Android channel id `new_orders`. No name, phone, address, note (FR-26). Delivery settings (importance, priority, expiry one hour, interruption level): ADR-0024 v1.1 [v1.14 | 2026-10-31]. Tap opens `GET /v1/admin/orders/{order_code}` after sign-in if needed (FR-26).
