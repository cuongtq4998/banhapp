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
| `order-request.json` | `POST /v1/orders` | Request body of the api.md example (headers `Idempotency-Key`, `X-Platform`, `X-App-Version` are not part of the file); 2 cakes at 50,000 plus a 20,000 fee is the expected 120,000 |
| `order-created.json` | `POST /v1/orders` | 201 exchange: `status`, `response_headers`, `body` with `order_code` and `created_at` only |
| `order-replay.json` | `POST /v1/orders` | 200 replay of the same key and body: same `body`, header `Idempotent-Replay: true` |
| `order-error-*.json` | `POST /v1/orders` | One error envelope per code of api.md 4.3 (`validation-failed` with two `fields[]`, `price-changed`, `min-qty`, `date-lead`, `date-horizon`, `date-capacity`, `product-unavailable`, `slot-unavailable`, `district-unserved`, `idempotency-key-required`, `header-invalid`, `idempotency-key-reused`, `rate-limited`, `payload-too-large`, `ordering-paused`, `service-unavailable`, `internal-error`) with the `details` the document states. The backend tests compare real answers with these files, ignoring `request_id` |
