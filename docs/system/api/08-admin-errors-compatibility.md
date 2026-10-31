# API Specification: Admin error catalogue, compatibility, traceability

Part of [api.md](../api.md) (index, version, change log), sections 11 to 13. New in v1.13 [v1.13 | 2026-10-31]; `CODE_LOCKED` removed in v1.15 [v1.15 | 2026-10-31] (no address lock, Q-20); `DEVICE_NOT_FOUND` removed and `EMAIL_TAKEN` narrowed in v1.16 [v1.16 | 2026-10-31]. The envelope, `message_key` rules and unknown-code behaviour of section 5 apply. Message keys belong to the admin UI document (canvas-ui); keys below are proposed names until that document lists them.

## 11. Admin error catalogue

| Code | HTTP | Top-level `message_key` | Meaning | Client behaviour |
| ---- | ---- | ----------------------- | ------- | ---------------- |
| UNAUTHENTICATED | 401 | `ERR_ADMIN_SIGN_IN_REQUIRED` | No or invalid access token | Try refresh once, else sign-in screen |
| ACCESS_TOKEN_EXPIRED | 401 | `ERR_ADMIN_SIGN_IN_REQUIRED` | Access token past 300 s | Refresh, repeat the request once |
| SESSION_REVOKED | 401 | `ERR_ADMIN_SESSION_ENDED` | Signed out (also by "sign out all other phones"), account deactivated, or refresh credential reused | Clear local data (BR-7), sign-in screen with the message |
| SESSION_EXPIRED | 401 | `ERR_ADMIN_SESSION_ENDED` | No use for 7 days | Same |
| FORBIDDEN | 403 | `ERR_ADMIN_FORBIDDEN` | Role too low (staff on `/v1/owner/*`) | Hide the area; show the message if reached |
| CODE_INVALID | 422 | `ERR_CODE_INVALID` | Wrong, unknown or used code (also for unregistered addresses) | Message on the code field |
| CODE_EXPIRED | 422 | `ERR_CODE_EXPIRED` | Code older than 10 minutes, or void after 5 wrong entries: "no longer valid, request a new code" | Offer resend |
| CODE_RESEND_WAIT | 429 | `ERR_CODE_RESEND_WAIT` | Less than 30 s since the last code | Disable resend, count down `retry_after_seconds` |
| CODE_REQUEST_LIMIT | 429 | `ERR_CODE_REQUEST_LIMIT` | Hourly, daily or per-address limit | Show the wait |
| ORDER_NOT_FOUND | 404 | `ERR_ORDER_NOT_FOUND` | Unknown, finished and older than 90 days, or not visible | Back to the list |
| ORDER_STATE_CHANGED | 409 | `ERR_ORDER_STATE_CHANGED` | Stale view; `details.order` is current | Show current status and message |
| STATUS_TRANSITION_INVALID | 422 | `ERR_ORDER_STATUS_INVALID` | Pair not allowed | Refresh the detail |
| CANCEL_REASON_REQUIRED | 422 | `ERR_CANCEL_REASON_REQUIRED` | Cancel without a valid reason | Keep the cancel step open |
| LAST_ACTIVE_CAKE, LAST_ACTIVE_DISTRICT, LAST_ACTIVE_SLOT | 409 | `ERR_LAST_ACTIVE_CAKE`, `ERR_LAST_ACTIVE_DISTRICT`, `ERR_LAST_ACTIVE_SLOT` | BR-11 | Show the message, keep the form |
| CAKE_LIMIT_REACHED | 409 | `ERR_CAKE_LIMIT` | 12 cakes not removed | Message |
| STAFF_LIMIT_REACHED | 409 | `ERR_STAFF_LIMIT` | 30 active staff | Message |
| EMAIL_TAKEN | 409 | `ERR_EMAIL_TAKEN` | Address is already an account address | Message on the form |
| OWNER_PROTECTED | 409 | `ERR_SERVER` | Deactivation of the owner | Control is not offered |
| SLOT_DUPLICATE | 422 | `ERR_SLOT_DUPLICATE` | Same start and end as another slot | Message on the form |
| IMAGE_TOO_LARGE | 413 | `ERR_IMAGE_TOO_LARGE` | Image over 5 MB | Message on the image field |

Field-level codes in `fields[]` (`NAME_TAKEN`, `IMAGE_REQUIRED`, `IMAGE_TYPE_UNSUPPORTED`, `IMAGE_DIMENSIONS_INVALID`, `EMAIL_INVALID`, `*_REQUIRED`, `*_OUT_OF_RANGE`) follow the rule of section 5: the client reads `fields[].message_key`. Existing codes reused: `VALIDATION_FAILED`, `RATE_LIMITED` (signed-in routes), `PAYLOAD_TOO_LARGE`, `HEADER_INVALID`, `NOT_FOUND`, `SERVICE_UNAVAILABLE`, `INTERNAL_ERROR`.

Rules: 401 and 403 bodies never say whether an account exists. `CODE_*` errors are the same for registered and unknown addresses. Limit messages carry `Retry-After` and `details.retry_after_seconds`.

## 12. Compatibility

Additive within `v1` as in section 6. Admin and customer apps share `v1`; the admin apps send `X-App-Version` and the server may later answer 426-style `APP_UPDATE_REQUIRED` (not defined now). Customer endpoints change only as listed in the change log: the catalog may hold up to 12 products and uploaded `image_url` values (additive); `POST /v1/orders` per-phone rule (api/03 step 7).

## 13. Traceability

Every endpoint of the admin index carries FR and BR (PRD v1.6, 27 FR and 14 BR) in api/05. Fields trace to data-model/04 and 05: `account`, `device_session`, `auth_code`, `customer_order`, `order_event`, `product`, `product_image`, `shop_setting`, `district`, `delivery_slot`, `settings_change`. FR-27 maps to `POST /v1/orders` only. Error codes removed in v1.16: `DEVICE_NOT_FOUND`; none of the other admin codes depends on a removed feature. Acceptance criteria (AC-1 to AC-48) map to these endpoints through their FRs [v1.16 | 2026-10-31].
