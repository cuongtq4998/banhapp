# API Specification: Conventions, endpoint index, shared schemas

Part of [api.md](../api.md) (index, version, change log), sections 1 to 3. Moved from api.md v1.9 with the wording unchanged unless a line carries a newer label [v1.10 | 2026-10-27].

## 1. Conventions

| Topic | Rule |
| ----- | ---- |
| Base path and version | `https://<API_HOST>/v1`. The version is in the path (section 6) |
| Format | JSON, UTF-8, `Content-Type: application/json`. Field names `snake_case` as in data-model.md |
| Money | Integer VND (whole dong), field suffix `_vnd` |
| Dates and times | Dates `YYYY-MM-DD` in shop time (Asia/Ho_Chi_Minh). Slot times `HH:MM`. Instants ISO 8601 UTC with `Z` |
| Authentication | None for the customer endpoints (anonymous customer, auth.md). Staff endpoints are a later slice and use a separate path prefix `/v1/staff` (reserved) |
| Request headers | `X-Platform: ios` or `android` (required on `POST /orders`), `X-App-Version: <semver>` (required on `POST /orders`), `Idempotency-Key: <uuid>` (required on `POST /orders`) |
| Response headers | `X-Request-Id` (uuid, echoed in logs), `Cache-Control` as stated per endpoint |
| Idempotency | `POST /v1/orders` only (section 4.3). `GET` is safe |
| Pagination | Not used (all lists are short and fixed) |
| Rate limits | Table below; excess answers 429 `RATE_LIMITED` with `Retry-After` (seconds) |
| Body limit | 8 KB: exactly 8,192 bytes pass, 8,193 or more answer 413 `PAYLOAD_TOO_LARGE`. Vapor rejects a body of `maxSize` bytes or more, so the configured `maxSize` is 8 KB + 1 [v1.4 \| 2026-10-26] |
| Client timeouts | Order submission 10 s; reads 15 s (ADR-0007). On the free trial host the first request after idle can take about 1 minute: the apps retry reads once and retry orders with the same key (ADR-0003) [v1.1 | 2026-10-25] |
| Unknown fields | Ignored in responses by clients; rejected with `VALIDATION_FAILED` in requests (typos must not pass silently); Swift `Codable` ignores unknown keys, so the backend checks the key set before decoding [v1.1 | 2026-10-25] |

Rate limits (per client IP, in-memory limiter; numbers are configuration, defaults shown). Rules [v1.6 | 2026-10-26] (ADR-0017): the read group is one shared budget per client address, not one per route; every request that reaches the limiter counts, including 200, 304 and 404; a request answered 429 does not count. The window is a fixed 60 seconds per address: it starts at that address's first counted request and ends 60 seconds later; the next counted request after the end starts a new window for that address (windows of different addresses are independent, there is no global reset) [v1.7 | 2026-10-26]. The limiter stores at most 10,000 addresses (a code constant, not configuration): when a new address arrives and the table is full, expired windows are removed first, and if it is still full the entry with the oldest window start is evicted, so memory is bounded and the limiter fails open for the evicted address, never closed for a new one. Only `GET` and `HEAD` requests are counted by this read budget (`POST /v1/orders` has its own limits); `HEAD` is answered like `GET` and counts, and clients do not use it. The counted address is the connection address, or with `TRUST_PROXY=true` the last entry of `X-Forwarded-For`, which is right only for exactly one trusted proxy in front of the API (deployment.md section 3); ADR-0019 (Proposed) replaces the boolean by a verified trusted hop count [v1.9 | 2026-10-27]. `Retry-After` is the whole seconds left in the window, rounded up, at least 1 (so between 1 and 60). Catalog refresh rule of the apps (ADR-0011): a revalidation is one counted request (304 counts), at most one per 30 seconds per app in the background [v1.8 | 2026-10-26]. A catalog load with four images is five requests, so 120 per minute serves about 20 cold-start customers a minute behind one address; the number is configuration (`RATE_LIMIT_READ_PER_MINUTE`) and the 429 alert in deployment.md watches it.

| Group | Limit |
| ----- | ----- |
| `GET /v1/*`, `/healthz`, `/privacy`, `/assets/*` (one shared budget) | 120 requests per minute |
| `POST /v1/orders` | 10 requests per hour, and 5 accepted orders per normalised phone number per 24 hours |

Error format (all non-2xx JSON responses):

```json
{
  "error": {
    "code": "DATE_CAPACITY",
    "message_key": "ERR_DATE_CAPACITY",
    "fields": [ { "field": "customer.phone", "code": "PHONE_INVALID", "message_key": "ERR_PHONE_INVALID" } ],
    "details": { }
  },
  "request_id": "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0001"
}
```

`code` is machine-readable and stable. `message_key` is the UI document key (design/place-order-ui.md section 8); clients show the text for the key, never server text. The top-level `message_key` is fixed per code (column "Top-level `message_key`" in section 5); `fields[]` entries carry their own keys. [v1.3 | 2026-10-26] `fields` appears only for `VALIDATION_FAILED`. `details` is specific to the code (stated per error). `request_id` helps support.

## 2. Endpoint Index

| Method | Path | Auth / role | Purpose | FR / BR traced |
| ------ | ---- | ----------- | ------- | -------------- |
| GET | /v1/catalog | None (anonymous) | Shop information, the active products (normally one to four), districts with fees, slots and ordering parameters | FR-2, FR-3, FR-4, FR-5, FR-7, FR-8, BR-3, BR-5, BR-10, BR-11 |
| GET | /v1/availability | None | Per date: can the date hold an order of N cakes | FR-6, FR-10, BR-1, BR-2, BR-8, AC-7, AC-8, AC-24 |
| POST | /v1/orders | None | Create an order and return its code | FR-8, FR-9, FR-10, FR-11, FR-13, FR-16, FR-17, FR-18, BR-1 to BR-8, BR-11 |
| GET | /healthz | None | Liveness and database check for monitoring | Operations (deployment.md) |
| GET | /privacy | None | Privacy statement page for store listings | PRD section 8 Privacy, Q-T4 |
| GET | /assets/* | None | Product images and shop logo (static) | FR-3 |
| (reserved) | /v1/staff/* | staff, owner | Later slice | Out of scope (auth.md) |

FR-1 (launch screen), FR-12, FR-14, FR-15, FR-19 need no endpoint (client behaviour; the API exposes no payment data, FR-19).

## 3. Shared schemas

`Product`: `{ "product_id": uuid, "slug": string, "name": string, "description": string, "price_vnd": int, "image_url": string }`

`District`: `{ "district_id": uuid, "name": string, "delivery_fee_vnd": int }`

`Slot`: `{ "slot_id": uuid, "start": "HH:MM", "end": "HH:MM" }`

