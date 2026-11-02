# Contract fixtures

JSON samples of API requests and responses (docs/system/api.md). The backend,
iOS and Android test suites all read these files; a change here is a contract
change and needs the owner of `docs/system/api.md` to agree first.

Fake data only. This repository is public.

| File | Endpoint | Meaning |
| ---- | -------- | ------- |
| `healthz-ok.json` | `GET /healthz` | 200, process (and database when `?deep=1`) healthy |
| `healthz-degraded.json` | `GET /healthz?deep=1` | 503, database query failed or timed out |
| `error-date-capacity.json` | any | Error envelope without `fields` (api.md section 1) |
| `error-validation-failed.json` | `POST /v1/orders` | Error envelope with `fields[]` |
| `error-not-found.json` | any unknown path | Envelope for routing errors (code `NOT_FOUND`, proposed addition to api.md section 5) |
| `error-rate-limited.json` | any | `RATE_LIMITED` envelope; `details.retry_after_seconds` equals the `Retry-After` header (api.md section 5) |
| `catalog-ok.json` | `GET /v1/catalog` | 200 with the four sample cakes (same rows as `backend/db/seed/sample.sql`), `image_url` relative to the API host with `?v=<8 hex of the file SHA-256>` |
| `catalog-empty.json` | `GET /v1/catalog` | 200 with no active product, district or slot (no active rows); apps show their empty state |
| `catalog-not-modified.json` | `GET /v1/catalog` | Revalidation exchange: `If-None-Match` matches, answer 304, headers only, `body` is null. The ETag value is a placeholder; real ones are the first 32 hex characters of the SHA-256 of the body |
| `error-service-unavailable.json` | any | `SERVICE_UNAVAILABLE` envelope (database unreachable); no `Retry-After` |
| `availability-ok.json` | `GET /v1/availability?cakes=3` | 200 for server date 2026-11-02 with `lead_days` 2, `max_days_ahead` 30, daily limit 100: 31 dates, the first two `TOO_SOON`, 2026-11-05 and 2026-11-20 `FULL` (so cakes 3 does not fit; 2026-11-05 holds 98, 2026-11-20 holds 100), the rest available with `reason` null |
| `validation.json` | input rules (ADR-0009 v1.2) | One canonical shape, `version` 2. Keys: `version`, `phone_pattern`, `phone` (`{input, valid, normalized, e164, reason?}`; `normalized` and `e164` only when valid), `text_limits` (`{name, address, note}`), `text` (`{field, value, valid, reason?}` or `{field, repeat, count, valid, reason?}` with `repeat` a string repeated `count` times), `decomposed` (`{composed, decomposed, length_after_nfc}`), `quantity` (`{per_cake, valid}`), `quantity_max_per_cake`. Read by backend, iOS and Android |
| `order-request.json` | `POST /v1/orders` | Request body of the api.md example (headers `Idempotency-Key`, `X-Platform`, `X-App-Version` are not part of the file); 2 cakes at 50,000 plus a 20,000 fee is the expected 120,000 |
| `order-created.json` | `POST /v1/orders` | 201 exchange: `status`, `response_headers`, `body` with `order_code` and `created_at` only |
| `order-replay.json` | `POST /v1/orders` | 200 replay of the same key and body: same `body`, header `Idempotent-Replay: true` |
| `order-error-*.json` | `POST /v1/orders` | One error envelope per code of api.md 4.3 (`validation-failed` with two `fields[]`, `price-changed`, `min-qty`, `date-lead`, `date-horizon`, `date-capacity`, `product-unavailable`, `slot-unavailable`, `district-unserved`, `idempotency-key-required`, `header-invalid`, `idempotency-key-reused`, `rate-limited`, `payload-too-large`, `ordering-paused`, `service-unavailable`, `internal-error`) with the `details` the document states. The backend tests compare real answers with these files, ignoring `request_id` |

## admin/

Admin sign-in and session exchanges (docs/system/api/05, api/06, api/08; admin-orders slice B1). Exchange files hold `request` (optional `headers`, `body`), `status` and `body`; token values are placeholders, so tests compare key sets and value types. `error-*.json` are error envelopes compared with the real answers, ignoring `request_id`.

| File | Endpoint | Meaning |
| ---- | -------- | ------- |
| `code-request.json` | `POST /v1/auth/code-requests` | 202, same body for every address |
| `session-created.json` | `POST /v1/auth/sessions` | 201 with tokens, `device_id`, `account`, `server_date` |
| `refresh-ok.json` | `POST /v1/auth/refresh` | 200 with a new pair |
| `me.json` | `GET /v1/admin/me` | 200 |
| `error-unauthenticated`, `-access-token-expired`, `-session-revoked`, `-session-expired`, `-forbidden` | admin routes | 401 and 403 envelopes |
| `error-code-invalid`, `-code-expired`, `-code-resend-wait`, `-code-request-limit`, `-validation-email` | `/v1/auth` | 422 and 429 envelopes; limits carry `retry_after_seconds` |
| `orders-list.json` | `GET /v1/admin/orders` | 200 list: `items[]` (with `expected_delivery_date`, `list_date`), `next_cursor` (null at the end), `unfinished_count`, `server_date` |
| `order-detail.json` | `GET /v1/admin/orders/{order_code}` | 200 detail: process fields, `allowed_actions`, `expected_date_range`, fee fields, `date_changes[]`, `fee_corrections[]`, `delivery_fee_entry`, `last_change` |
| `order-status-change.json` | `POST /v1/admin/orders/{order_code}/status` | Request body and the 200 detail after cancelling |
| `error-order-not-found`, `-status-transition-invalid`, `-cancel-reason-required`, `-order-state-changed` | status route | 404, 422 and 409 envelopes; the 409 carries `details.order` (the current detail) |
| `order-detail-received`, `-delivery-date-scheduled` (two `date_changes`), `-delivery-started` (fee 25 000), `-delivery-started-free` (fee 0), `-fee-corrected` (two `fee_corrections`) | detail by status; the last one is the `PUT .../delivery-fee` answer | 200 details |
| `error-status-transition-invalid-cancel`, `error-order-state-changed-date`, `-state-changed-fee` | status, date and fee routes | 422 and 409 envelopes; the 409 carries `details.order` |
| `error-validation-expected-date-past`, `-expected-date-too-far`, `error-validation-fee-required`, `-fee-invalid`, `error-fee-correction-not-allowed` | date and fee routes | 422 envelopes; the date ones carry `details.expected_date_range` |

Owner settings and staff (docs/system/api/07; admin-orders slices B4 and B5), in `admin/`. Ids and addresses are placeholders; tests compare key sets and value kinds.

| File | Endpoint | Meaning |
| ---- | -------- | ------- |
| `owner-settings.json` | `GET /v1/owner/settings` | 200 with `shop`, `ordering`, `cakes`, `districts`, `slots`, `cake_count_max`, `staff_count_max` |
| `owner-shop-saved.json` | `PUT /v1/owner/settings/shop` | Request and the 200 section |
| `owner-ordering-saved.json` | `PUT /v1/owner/settings/ordering` | 200 section plus `over_limit` and `count` true at save time |
| `owner-ordering-impact.json` | `GET /v1/owner/settings/ordering/impact?daily_limit=60` | 200 preview, writes nothing |
| `owner-district-created.json`, `owner-slot-created.json` | `POST /v1/owner/districts`, `/slots` | 201 |
| `owner-staff-list.json`, `owner-staff-created.json`, `owner-staff-deactivated.json` | `/v1/owner/staff` | `{ accounts: [...] }` (owner first), 201 account, 200 account |
| `error-settings-validation`, `-staff-validation` | settings and staff writes | 422 with every problem in `fields[]` (`ERR_FIELD_*` keys) |
| `error-last-active-district`, `-last-active-slot`, `-slot-duplicate`, `-email-taken`, `-staff-limit-reached`, `-owner-protected` | districts, slots, staff | 409 and 422 envelopes |
| `owner-cake-created.json`, `owner-cake-updated.json` | `POST /v1/owner/cakes` (multipart), `PATCH /v1/owner/cakes/{id}` | 201 and 200 cake; `image_url` of an uploaded cake is `/assets/cakes/<id>?v=<8 hex>`; `DELETE` answers 204 |
| `error-cake-validation`, `-cake-name-taken` | `POST /v1/owner/cakes` | 422 with the `image` codes and `NAME_TAKEN` in `fields[]` |
| `error-cake-limit-reached`, `-last-active-cake`, `-image-too-large` | cakes | 409 (13th cake, last active cake) and 413 envelopes |
