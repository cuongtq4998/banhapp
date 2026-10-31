# API Specification: Admin session, devices, push token, orders

Part of [api.md](../api.md) (index, version, change log), sections 10.6 to 10.12. New in v1.13 [v1.13 | 2026-10-31]. Auth: Bearer access token, roles owner and staff unless stated (api/05 section 9). All responses `no-store`.

### 10.6 GET /v1/admin/me and DELETE /v1/admin/session

`GET /v1/admin/me` returns `{ "account": { "name", "role", "has_backup_email" }, "device_id", "server_date", "order_window_days": 90 }` (`has_backup_email` only for the owner). `DELETE /v1/admin/session` revokes the calling device (`signed_out`), deletes its push token, answers 204; repeating it answers 401. FR-4, FR-35.

### 10.7 Devices

`GET /v1/admin/devices` returns `{ "devices": [ { "device_id", "account_name", "device_name", "platform", "last_used_at", "created_at", "is_current" } ] }`. The owner gets every active session of every account; staff get only their own (AC-56). `DELETE /v1/admin/devices/{device_id}` revokes it (`revoked_by_owner`, or `signed_out` when it is the caller's own), deletes its push token, 204. A staff caller naming another person's device gets 404 `DEVICE_NOT_FOUND` (not 403, to avoid hints). Revoking the current device is allowed. Example item: `{ "device_id": "5b0c2f6a-0000-4a00-8000-000000000001", "account_name": "Nhan Vien A", "device_name": "iPhone", "platform": "ios", "last_used_at": "2026-11-02T03:15:09Z", "created_at": "2026-10-30T01:00:00Z", "is_current": true }`.

### 10.8 PUT and DELETE /v1/admin/push-token

`PUT` body `{ "platform": "ios"|"android", "token": string (1 to 512), "apns_environment": "production"|"sandbox" (required for ios) }`; 204. Replaces the token of the calling device and moves a token seen on another session to this one. `DELETE` removes it (204, also when absent). Errors: 422 `VALIDATION_FAILED`. Rate limit: shared. FR-31, FR-34 (the app does not call `PUT` when permission is denied).

### 10.9 GET /v1/admin/orders

| Query | Type | Rules |
| ----- | ---- | ----- |
| status | repeated | `New`, `Confirmed`, `Completed`, `Cancelled`, or `all`. Absent means `New` and `Confirmed` (BR-13) |
| date_preset | string | `today` or `tomorrow` (shop date on the server). Excludes `date_from`, `date_to` |
| date_from, date_to | date | Inclusive range of delivery dates; `date_from <= date_to`, at most 120 days apart |
| q | string | 2 to 50 characters; order code, part of the name, part of the phone (ADR-0029) |
| cursor | string | Opaque, from `next_cursor` |

Unknown parameters are rejected as `VALIDATION_FAILED`. Only orders placed in the last 90 days are returned, whatever the filters (FR-41). Sort: `delivery_date`, slot start, `created_at`, id, ascending (BR-13). 200 response:

| Field | Type | Notes |
| ----- | ---- | ----- |
| items | array (at most 50) | `order_code`, `status`, `customer_name`, `delivery_date`, `slot` (`start`, `end`), `total_cakes`, `total_vnd`, `district_name`, `created_at` |
| next_cursor | string or null | Null at the end; no row repeats between pages |
| new_count | integer | Orders in New inside the window, whatever the filters (FR-12) |
| server_date | date | |
| server_time | instant | "Updated at" (AC-21) |

Errors: 401, 422 `VALIDATION_FAILED` (`fields` name the parameter), 429, 503. Side effects: none. Review accounts see only `is_demo` rows. Example: `GET /v1/admin/orders?status=New&date_preset=today` returns `{ "items": [ { "order_code": "BT-7K3M9Q", "status": "New", "customer_name": "Tran Thi B", "delivery_date": "2026-11-02", "slot": { "start": "08:00", "end": "10:00" }, "total_cakes": 2, "total_vnd": 120000, "district_name": "Quan An Phu", "created_at": "2026-10-31T03:15:09Z" } ], "next_cursor": null, "new_count": 1, "server_date": "2026-11-02", "server_time": "2026-11-02T03:20:00Z" }`.

### 10.10 GET /v1/admin/orders/{order_code}

`order_code` matches `^BT-[2-9A-HJKMNP-Z]{6}$` (else 404). 200: the summary fields of 10.9 plus `customer_phone` (E.164), `customer_address`, `note`, `items` (`product_name`, `quantity`, `unit_price_vnd`, `line_total_vnd`; stored values, FR-14), `items_subtotal_vnd`, `delivery_fee_vnd`, `cancel_reason` (or null), `allowed_actions` (subset of `confirm`, `complete`, `cancel`, computed from the status; empty for final states), and `history`, oldest first: `{ "event_type", "from_status", "to_status", "actor_name", "actor_kind" ("customer"|"staff"|"owner"|"system"), "reason", "at" }`. A code that does not exist, an order older than 90 days and (for review accounts) a non-demo order all answer 404 `ORDER_NOT_FOUND`. This route is what a push tap calls (FR-33). The response is personal data: never logged. FR-14, FR-20, FR-41.

### 10.11 POST /v1/admin/orders/{order_code}/status

Request: `expected_status` (the status the client shows), `to_status`, `cancel_reason` (required when `to_status` is `Cancelled`, one of `customer_asked`, `day_full`, `cannot_deliver`, `cannot_reach_customer`, `fake_spam`; forbidden otherwise). Allowed pairs: New to Confirmed, New to Cancelled, Confirmed to Completed, Confirmed to Cancelled. Checks and transaction: ADR-0028. Responses:

| Status | Code | Body |
| ------ | ---- | ---- |
| 200 | | The order detail of 10.10 after the change; header `Idempotent-Replay: true` when the repeat rule of ADR-0028 applied |
| 404 | `ORDER_NOT_FOUND` | Unknown or outside the window |
| 409 | `ORDER_STATE_CHANGED` | `details.order` is the current detail of 10.10; the client shows the current status (FR-19) |
| 422 | `STATUS_TRANSITION_INVALID` | The pair is not allowed (for example New to Completed, or from a final state); `details.status` is `expected_status` |
| 422 | `CANCEL_REASON_REQUIRED` | Cancelled without a valid reason |
| 422 | `VALIDATION_FAILED` | Unknown field, bad enum, reason with a non-cancel target |

Side effects (one transaction): status and `cancel_reason` set; `order_event` with actor, actor name and reason; on cancel `day_load` reduced by `total_cakes` (trigger, BR-3). No notification to the customer. Idempotency: ADR-0028. Example request `{ "expected_status": "New", "to_status": "Cancelled", "cancel_reason": "customer_asked" }`; example 409 body `{ "error": { "code": "ORDER_STATE_CHANGED", "message_key": "ERR_ORDER_STATE_CHANGED", "details": { "order": { "order_code": "BT-7K3M9Q", "status": "Confirmed" } } }, "request_id": "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0002" }` (order shortened).

### 10.12 Push notification payload (for the clients)

Not an endpoint. APNs alert `title-loc-key` `PUSH_NEW_ORDER_TITLE`, `loc-key` `PUSH_NEW_ORDER_BODY`, `loc-args` `[order_code, cakes, "dd/MM/yyyy"]`; custom field `order_code`; FCM `notification.title_loc_key`, `body_loc_key`, `body_loc_args` and `data.order_code`; Android channel id `new_orders`. No name, phone, address, note (FR-32, AC-49). Tap opens `GET /v1/admin/orders/{order_code}` after sign-in if needed (FR-33).
