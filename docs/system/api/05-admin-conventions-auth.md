# API Specification: Admin conventions, endpoint index, sign-in endpoints

Part of [api.md](../api.md) (index, version, change log), sections 9 and 10.1 to 10.5. New in v1.13 [v1.13 | 2026-10-31]; sign-in rules aligned with PRD v1.4 in v1.15 [v1.15 | 2026-10-31]. Decisions: ADR-0022, ADR-0023, ADR-0028 to ADR-0031. The reserved prefix `/v1/staff` is released; it is not used.

## 9. Admin conventions

| Topic | Rule |
| ----- | ---- |
| Prefixes | `/v1/auth/*` public sign-in routes; `/v1/admin/*` any signed-in owner or staff; `/v1/owner/*` owner only. Role is checked by a `RequireRole` middleware per route group, then again in the service for rules that need the account (FR-5, FR-21) |
| Authentication | `Authorization: Bearer <access_token>` (`at_<device_id>_<secret>`, 300 s). Missing, malformed, unknown, expired or revoked: 401 `UNAUTHENTICATED` (expired: `ACCESS_TOKEN_EXPIRED`, the client refreshes once and retries). Role too low: 403 `FORBIDDEN`. No existence hints |
| Headers | `X-Platform` (`ios`, `android`) and `X-App-Version` (`N.N.N`) required on every admin route (400 `HEADER_INVALID`). `Idempotency-Key` is not used; conflicts are handled by `expected_status` (ADR-0028) |
| Format | JSON UTF-8, `snake_case`, as section 1. Exceptions: `POST /v1/owner/cakes` is `multipart/form-data` (ADR-0025) |
| Cache | Every admin response: `Cache-Control: no-store`, `Vary: Authorization` |
| Body limit | 8 KB as section 1. Only `POST /v1/owner/cakes` differs: 5,308,416 bytes (`IMAGE_MAX_BYTES` 5,242,880 + 65,536); a larger `Content-Length` is refused with 413 before the body is read; role is checked first (ADR-0025) [v1.14 | 2026-10-31] |
| Pagination | Order list only: keyset cursor, 50 rows (ADR-0029) |
| Rate limits | `/v1/auth/*`: per address and global limits of auth.md section 4.2 (429 `CODE_*`); per client address 20 requests an hour on code and recovery requests and 60 an hour on the other `/v1/auth` routes; 401 answers on `/v1/admin` and `/v1/owner` count 60 a minute per client address (auth/abuse-secrets-threats.md 4.2) [v1.14 | 2026-10-31]. Signed-in routes: 240 requests a minute per device session (`RATE_LIMIT_ADMIN_PER_MINUTE`), then 429 `RATE_LIMITED` |
| Logging | No e-mail address, token, code or customer data in logs or error bodies (BR-15). Log fields: request id, route, status, duration, role, platform |
| Errors | Envelope of section 1; new codes in api/08 |
| Dates | `YYYY-MM-DD` shop dates; `created_at` instants UTC |

## Endpoint index (admin)

| Method | Path | Role | Purpose | FR / BR |
| ------ | ---- | ---- | ------- | ------- |
| POST | /v1/auth/code-requests | public | Request a sign-in code | FR-1, FR-3, FR-6, BR-5 |
| POST | /v1/auth/sessions | public | Sign in with address and code | FR-2, FR-4, FR-6, BR-5, BR-6 |
| POST | /v1/auth/refresh | public (refresh token) | Rotate credentials | FR-36, BR-6 |
| POST | /v1/auth/recovery-requests | public | Request the two recovery codes | FR-43, BR-17 |
| POST | /v1/auth/recovery-sessions | public | Sign in with both codes | FR-43, BR-17 |
| GET | /v1/admin/me | owner, staff | Account, role, server date | FR-5, FR-21 |
| DELETE | /v1/admin/session | owner, staff | Sign out this device | FR-4, FR-35 |
| GET | /v1/admin/devices | owner (all), staff (own) | Device list | FR-37 |
| DELETE | /v1/admin/devices/{device_id} | owner (any), staff (own) | Revoke a device | FR-37, FR-35, BR-8 |
| PUT, DELETE | /v1/admin/push-token | owner, staff | Register or remove this device's push token | FR-31, FR-35 |
| GET | /v1/admin/orders | owner, staff | List, filter, search, Unfinished view (`view=unfinished`) and its count | FR-8 to FR-13, FR-41, FR-48 to FR-51, BR-13, BR-20, BR-27 |
| GET | /v1/admin/orders/{order_code} | owner, staff | Detail with history | FR-14, FR-20, FR-33, FR-41, FR-48 |
| POST | /v1/admin/orders/{order_code}/status | owner, staff | Confirm, complete, cancel | FR-16 to FR-19, BR-2 to BR-4, BR-16 |
| GET | /v1/owner/settings | owner | All settings, cakes, districts, slots | FR-21 to FR-26, FR-38 to FR-40 |
| PUT | /v1/owner/settings/shop | owner | Shop name, greeting, contacts | FR-26, FR-28 |
| GET, PUT | /v1/owner/settings/ordering (+ `/impact`) | owner | Daily limit, lead days, minimum cakes; preview | FR-24, FR-40, BR-9, BR-10, BR-21 |
| POST, PATCH | /v1/owner/districts, /v1/owner/districts/{id} | owner | Add, change, activate | FR-23, BR-11 |
| POST, PATCH | /v1/owner/slots, /v1/owner/slots/{id} | owner | Add, change, activate | FR-25, BR-9, BR-11 |
| POST, PATCH, DELETE | /v1/owner/cakes, /v1/owner/cakes/{id} | owner | Add (multipart), change, remove | FR-22, FR-38, FR-39, BR-18, BR-19 |
| GET, POST, PATCH | /v1/owner/staff, /v1/owner/staff/{id} | owner | List, add, deactivate or reactivate | FR-27, BR-7, BR-8 |
| PUT, POST | /v1/owner/backup-email (+ `/confirmation`) | owner | Register or change the backup address | FR-42 |
| GET | /assets/cakes/{product_id} | public | Uploaded cake image | FR-38 |

## 10. Admin endpoint specs

### 10.1 POST /v1/auth/code-requests

Request `{ "email": string }` (required, valid format after trim and lower case, at most 254 characters; otherwise 422 `VALIDATION_FAILED` with field `email`). Response 202, always the same body, whether or not the address is registered: `{ "resend_after_seconds": 30, "expires_in_seconds": 600 }`. Side effects: a row in `auth_code` (also for unknown addresses), a mail only to an active account, sent after the response. Errors: 429 `CODE_RESEND_WAIT` (`details.retry_after_seconds`), 429 `CODE_REQUEST_LIMIT` (3 an hour per address and purpose, daily cap, per client address; `retry_after_seconds`), 503 `SERVICE_UNAVAILABLE`. A new request consumes the older codes. Idempotency: each request is a new code. Example: `{ "email": "nhanvien.a@example.com" }` returns `{ "resend_after_seconds": 30, "expires_in_seconds": 600 }`.

### 10.2 POST /v1/auth/sessions

Request: `email`, `code` (6 digits), `installation_id` (uuid), `device_name` (1 to 60 characters, no control characters). The app builds it from the device model and system version, never from a user-assigned name: iOS `iPhone (iOS 17.5)`, Android `<Manufacturer> <Model> (Android 14)` (R-29) [v1.14 | 2026-10-31]. Headers `X-Platform`, `X-App-Version` required. 201 response:

| Field | Type | Notes |
| ----- | ---- | ----- |
| access_token, refresh_token | string | Format of auth.md section 3 |
| access_expires_in | integer | 300 |
| device_id | uuid | The session |
| account | object | `name`, `role` (`owner` or `staff`), `has_backup_email` (owner only) |
| server_date | date | |

Checks in order: the latest unconsumed code for the address and purpose `sign_in` (none, or wrong: 422 `CODE_INVALID` and `wrong_count` + 1; past `expires_at`, or void after 5 wrong entries: 422 `CODE_EXPIRED`, meaning "request a new code"). The 5th wrong entry already answers `CODE_EXPIRED` and voids the code; there is no lock on the address (Q-20, BR-5). Success marks the code consumed, decides `is_new_device` (owner only: no unrevoked, unexpired session of the account with this `installation_id`), revokes an older session of the same `installation_id` (`replaced`), creates the session and writes `security_event`; if `is_new_device`, the notice of FR-47 is sent after the response and its failure never changes the answer. Unknown and inactive addresses behave exactly as wrong codes [v1.15 | 2026-10-31]. Example response: `{ "access_token": "at_<DEVICE_ID>_<SECRET>", "refresh_token": "rt_<DEVICE_ID>_<SECRET>", "access_expires_in": 300, "device_id": "5b0c2f6a-0000-4a00-8000-000000000001", "account": { "name": "Nhan Vien A", "role": "staff" }, "server_date": "2026-11-02" }`.

### 10.3 POST /v1/auth/refresh

Request `{ "refresh_token": string }`. 200 response: `access_token`, `refresh_token`, `access_expires_in`. The server finds the session by the id inside the token. Match with the current hash: rotate, restart the 7 days. Match with the previous hash within 20 s of the last rotation: rotate again (lost response). Previous hash later, or no match: revoke the session (`reuse_detected`), 401 `SESSION_REVOKED`. Revoked, expired (7 days unused) or inactive account: 401 `SESSION_REVOKED` or `SESSION_EXPIRED`. Rate limit: shared admin limit per session id and per client address. Side effects: update of `device_session`. Idempotency: a repeat with the same old token inside 20 s returns a fresh pair (the earlier one dies).

### 10.4 POST /v1/auth/recovery-requests

Request `{ "email": string }` (the owner's address). Response 202, same body as 10.1. If the address is the active owner's and a confirmed backup address exists, two codes are created with one `challenge_id` and sent, one to each mailbox; otherwise a phantom challenge and no mail. Limits and errors as 10.1, counted separately from sign-in codes (purpose `recovery_owner`; BR-17) [v1.15 | 2026-10-31].

### 10.5 POST /v1/auth/recovery-sessions

Request: `email`, `owner_code`, `backup_code`, `installation_id`, `device_name`. Both codes must be correct, unexpired and unused, of the same challenge. Any failure adds 1 to `wrong_count` of both codes of the challenge and answers `CODE_INVALID` or `CODE_EXPIRED` without saying which code failed (AC-59); the 5th voids the attempt (`CODE_EXPIRED`) and leaves ordinary sign-in untouched. Success: both consumed, session created (`sign_in_method = recovery`), one notice sent to both addresses (no new-device notice), response as 10.2 plus `offer_device_list: true`. Errors as 10.2.
