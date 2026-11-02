# API Specification: Admin error catalogue, compatibility, traceability

Part of [api.md](../api.md) (index, version, change log), sections 11 to 13. Validation `message_key` stated in 11.1 in v1.29 [v1.29 | 2026-11-02]. Section 11.1 (order list and status field codes) added in v1.18 [v1.18 | 2026-11-01]. New in v1.13 [v1.13 | 2026-10-31]; `CODE_LOCKED` removed in v1.15 [v1.15 | 2026-10-31] (no address lock, Q-20); `DEVICE_NOT_FOUND` removed and `EMAIL_TAKEN` narrowed in v1.16 [v1.16 | 2026-10-31]. The envelope, `message_key` rules and unknown-code behaviour of section 5 apply. Message keys belong to the admin UI document (canvas-ui); keys below are proposed names until that document lists them.

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
| IMAGE_TOO_LARGE | 413 | `ERR_IMAGE_TOO_LARGE` | A file part over 5,242,880 bytes | Message on the image field |
| PAYLOAD_TOO_LARGE | 413 | `ERR_SERVER` | Cake upload request over 5,308,416 bytes (any other route: over 8 KB) [v1.20 | 2026-11-01] | Treat as a programming error; the app re-encodes below 5 MB |

Field-level codes in `fields[]` (owner routes, v1.19: `BODY_EMPTY` on field `body`, `FIELD_UNKNOWN`, `START_INVALID`, `END_INVALID`, `END_OUT_OF_RANGE`, `NAME_TAKEN` also for districts; `message_key` `ERR_FIELD_*`) and (`NAME_TAKEN`, `IMAGE_REQUIRED` (`ERR_FIELD_REQUIRED`), `IMAGE_TYPE_UNSUPPORTED` (`ERR_FIELD_TYPE_UNSUPPORTED`), `IMAGE_DIMENSIONS_INVALID` (`ERR_FIELD_DIMENSIONS_INVALID`), `IMAGE_INVALID` (`ERR_FIELD_INVALID`, two image files) [v1.20 | 2026-11-01], `EMAIL_INVALID`, `CODE_FORMAT`, `INSTALLATION_ID_INVALID`, `DEVICE_NAME_INVALID` (sign-in, api/05 10.2), `*_REQUIRED`, `*_OUT_OF_RANGE`) follow the rule of section 5: the client reads `fields[].message_key`. A repeated text field of the cake form is `<FIELD>_INVALID` [v1.20 | 2026-11-01]. Existing codes reused: `VALIDATION_FAILED`, `RATE_LIMITED` (signed-in routes), `PAYLOAD_TOO_LARGE`, `HEADER_INVALID`, `NOT_FOUND`, `SERVICE_UNAVAILABLE`, `INTERNAL_ERROR`.

### 11.1 Field codes of the order list and the status change [v1.18 | 2026-11-01]

All of these arrive as 422 `VALIDATION_FAILED` with the defect in `fields[]` (`field`, `code`, `message_key`). Decision [v1.29 | 2026-11-02]: the key is `ERR_SERVER` at the top level and in every `fields[]` entry of every admin validation error, until the UI document lists a per-field key; there is no `ERR_VALIDATION`. This matches api/04 section 5 (`VALIDATION_FAILED` is `ERR_SERVER`), the built backend and the fixtures `contracts/fixtures/admin/error-validation-*.json`; no code or fixture changes. Exceptions that carry their own key are the codes listed in section 11 and the owner field codes with `ERR_FIELD_*` below. The customer lookup route (api/10 10.14.6) follows the same keys: top level `ERR_SERVER`, field entries `ERR_FIELD_REQUIRED` or `ERR_FIELD_INVALID`, 429 `ERR_RATE_LIMITED` [v1.31 | 2026-11-02]. One response lists every defect found in the query; a client shows at most the first and treats any of them as a programming error, because the apps build these requests from fixed choices.

| Code | Field | Meaning |
| ---- | ----- | ------- |
| UNKNOWN_PARAMETER | the parameter name | Not one of `status`, `date_preset`, `delivery_date`, `q`, `cursor` (also `date_from`, `date_to`, `view`) |
| REPEATED_PARAMETER | the parameter name | The same parameter twice; no list-valued filter exists |
| STATUS_INVALID | `status` (list), `expected_status` or `to_status` (change) | Not `todo`, `all` or one of the four statuses (list); not one of the four statuses or missing (change) |
| DATE_INVALID | `delivery_date` | Not a real calendar date `YYYY-MM-DD` (`2026-02-31` is invalid) |
| DATE_PRESET_INVALID | `date_preset` | Not `today` or `tomorrow` |
| DATE_FILTER_CONFLICT | `delivery_date` | `date_preset` and `delivery_date` together |
| SEARCH_INVALID | `q` | After trimming, under 3 or over 50 characters; contains a control character (including NUL); looks like a phone number (only digits, spaces and `+-().`) with under 3 digits. An empty `q=` is invalid, an absent `q` is no search |
| CURSOR_INVALID | `cursor` | Not a cursor issued by the server (altered, truncated or from another API). The cursor is opaque: the client passes `next_cursor` back unchanged and, on this error, drops the cursor and reloads page 1 |
| UNKNOWN_FIELD | the body key | Canonical name for an unknown JSON key on admin order and device routes: status change (a key other than `expected_status`, `to_status`, `cancel_reason`, `expected_delivery_date`, `delivery_fee_vnd`), `PUT .../expected-delivery-date`, `PUT .../delivery-fee`, push token. The built owner and customer routes keep `FIELD_UNKNOWN` (api/04, api/07) [v1.28 | 2026-11-02] |
| EXPECTED_DATE_REQUIRED, EXPECTED_DATE_INVALID, EXPECTED_DATE_PAST, EXPECTED_DATE_UNCHANGED | `expected_delivery_date` | Missing, not a calendar date, before the shop's today, or equal to the stored date (order-process.md; api/09) [v1.24 | 2026-11-02] |
| FEE_REQUIRED, FEE_INVALID | `delivery_fee_vnd` | Missing at DeliveryStarted; not a whole number 0 to 10 000 000 [v1.24 | 2026-11-02] |
| FIELD_NOT_ALLOWED | the extra key | Date, fee or reason sent with a target that does not take it [v1.24 | 2026-11-02] |
| REASON_NOT_ALLOWED | `cancel_reason` | Reason sent with a target other than `Cancelled` |

Checks run in this order for the list: unknown or repeated names, `status`, preset against date, preset, date, `q`, `cursor`. Order data, `q` and the cursor are never logged (they can hold a name or a phone number).

Rules: 401 and 403 bodies never say whether an account exists. `CODE_*` errors are the same for registered and unknown addresses. Limit messages carry `Retry-After` and `details.retry_after_seconds`, at most 3600 (api/05 10.1) [v1.17 | 2026-11-01]. A refresh token that is malformed or unknown answers `SESSION_REVOKED`.

## 12. Compatibility

Additive within `v1` as in section 6. Admin and customer apps share `v1`; the admin apps send `X-App-Version` and the server may later answer 426-style `APP_UPDATE_REQUIRED` (not defined now). Customer endpoints change only as listed in the change log: the catalog may hold up to 12 products and uploaded `image_url` values (additive); `POST /v1/orders` per-phone rule (api/03 step 7).

## 13. Traceability

Every endpoint of the admin index carries FR and BR (PRD v1.6, 27 FR and 14 BR) in api/05. Fields trace to data-model/04 and 05: `account`, `device_session`, `auth_code`, `customer_order`, `order_event`, `product`, `product_image`, `shop_setting`, `district`, `delivery_slot`, `settings_change`. FR-27 maps to `POST /v1/orders` only. Error codes removed in v1.16: `DEVICE_NOT_FOUND`; none of the other admin codes depends on a removed feature. Acceptance criteria (AC-1 to AC-48) map to these endpoints through their FRs [v1.16 | 2026-10-31].
