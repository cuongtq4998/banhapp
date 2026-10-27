# API Specification

| Field        | Value |
| ------------ | ----- |
| Version      | 1.9 |
| Last updated | 2026-10-27 |
| Status       | Draft |
| Owner        | atlas-architect |
| Based on     | product/place-order.md v1.2; design/place-order-ui.md v1.0; data-model.md v1.0 |
| Related      | order-lifecycle.md; auth.md; ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0014, ADR-0017, ADR-0019 |

Decided: ADR-0010 is Accepted by the owner: option A, reject with `PRICE_CHANGED` and let the customer re-review (`expected_total_vnd` stays). [v1.1 | 2026-10-25] Backend framework is Vapor (ADR-0001); the conventions below are implemented as Vapor middleware. [v1.1 | 2026-10-25]

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

## 4. Endpoint Specs

### 4.1 GET /v1/catalog

Role: anonymous. Purpose: everything the app displays before ordering (FR-2, FR-3, FR-4, FR-7, FR-8). Request parameters: none; any query parameter is ignored (200, same body and same `ETag` as without it; never 422 or 5xx) [v1.6 | 2026-10-26]. Headers: optional `If-None-Match`.

200 response (`Cache-Control: no-cache`, `ETag` set; the app revalidates, ADR-0011):

| Field | Type | Notes |
| ----- | ---- | ----- |
| server_date | date | Today in shop time. Clients use it instead of the device date |
| shop | object | `name`, `greeting`, `phone_contact` (E.164), `zalo_contact` |
| settings | object | `min_qty`, `lead_days`, `max_days_ahead`, `max_qty_per_cake` (from `shop_setting`), `note_max_length` (a code constant, 200, the same bound as the `customer_order.note` column check; it is not a `shop_setting` column) [v1.6 \| 2026-10-26] |
| products | Product[] | Every active product, ordered by `sort_order`: one to four are normal (the owner may deactivate a cake). The server never pads or truncates the list; zero active products answers 200 with `[]` and the apps show the error screen (owner decision 2026-10-26, PRD FR-3) | [v1.6 | 2026-10-26]
| districts | District[] | Active districts, ordered |
| slots | Slot[] | Active slots, ordered |

Not included: `daily_limit` and remaining amounts (not shown to customers). `is_sample` is never returned.

ETag contract [v1.6 | 2026-10-26] (ADR-0017): a strong validator, the quoted lowercase hexadecimal SHA-256 of the exact response body bytes truncated to 32 characters (there is no 64-character form anywhere: the first 32 hexadecimal characters of the SHA-256, nothing else) [v1.7 | 2026-10-26], for example `"3f2a9c1e5b7d40a8c6e1f0b29d4a7c53"`. The body is encoded deterministically (fixed key order, no whitespace changes), so equal data gives an equal tag. `server_date` is in the body, so the tag changes at midnight shop time. `image_url` carries a content version (section 4.6), so a changed photo changes the tag. `If-None-Match` is compared with the weak comparison of RFC 9110 section 13.1.2: a comma-separated list is allowed, `W/` prefixes are ignored, `*` matches any current representation. A match answers `304` with an empty body and repeats `ETag`, `Cache-Control: no-cache`, `X-Request-Id` (RFC 9110 section 15.4.5 requires `ETag` and `Cache-Control` to be sent again); it does not repeat `Content-Type` or `Content-Length`. No match, or an invalid header value, answers the full 200. `HEAD` [v1.7 | 2026-10-26]: Vapor answers `HEAD` on a routed `GET` path like `GET` with the body removed (same status, same `ETag`, `If-None-Match` honoured). That is accepted and not promised: clients never send `HEAD`, it counts for the rate limit like `GET`, and no test pins its body. Unrouted methods still answer 404 (section 5). A 304 counts for the rate limit.

Errors: 429 `RATE_LIMITED`; 503 `SERVICE_UNAVAILABLE`.

Side effects: none. Idempotency: safe and repeatable.

Example response:

```json
{
  "server_date": "2026-11-02",
  "shop": { "name": "Tiệm Bánh An Nhiên", "greeting": "Chào bạn, mời đặt bánh tét.", "phone_contact": "+84900000000", "zalo_contact": "84900000000" },
  "settings": { "min_qty": 2, "lead_days": 2, "max_days_ahead": 30, "max_qty_per_cake": 99, "note_max_length": 200 },
  "products": [
    { "product_id": "0b8f1f0e-1111-4a00-8000-000000000001", "slug": "banana", "name": "Bánh tét chuối", "description": "Bánh chuối nướng thơm béo.", "price_vnd": 50000, "image_url": "/assets/images/banana.png?v=9c1e5b7d" }
  ],
  "districts": [ { "district_id": "0b8f1f0e-2222-4a00-8000-000000000001", "name": "Quận An Phú", "delivery_fee_vnd": 20000 } ],
  "slots": [ { "slot_id": "0b8f1f0e-3333-4a00-8000-000000000001", "start": "08:00", "end": "10:00" } ]
}
```

(All values are fake data; the list is shortened. Wording rule [v1.6 | 2026-10-26]: no seed value, example or fixture that can reach a screen contains a sample marker such as "mẫu", "sample", "test", "demo" or "fake" (AC-29); the word `is_sample` exists only in the database.)

### 4.2 GET /v1/availability

Role: anonymous. Purpose: the date grid on S-6 (FR-6). The server applies BR-1, BR-2 and BR-8.

| Query parameter | Type | Required | Rules |
| --------------- | ---- | -------- | ----- |
| cakes | integer | yes | Total cakes in the order, 1 to `max_qty_per_cake` times the number of active products (396 with four). Used for the capacity test [v1.6 \| 2026-10-26]. With zero active products the upper bound is 0, so **every** value of `cakes` is out of range and answers 422 (the apps do not call this endpoint then: S-5 is not reachable, UI section 5.5) [v1.9 \| 2026-10-27] |

200 response (`Cache-Control: no-store`):

| Field | Type | Notes |
| ----- | ---- | ----- |
| server_date | date | Today in shop time |
| dates | array | One entry for each date from `server_date` to `server_date + max_days_ahead`, inclusive |
| dates[].date | date | |
| dates[].available | boolean | True only if lead, horizon and capacity all pass |
| dates[].reason | string or null | `TOO_SOON` (before `server_date + lead_days`), `TOO_FAR` (after `server_date + max_days_ahead`, not returned in this list), `FULL` (remaining less than `cakes`), null when available |

Remaining amounts are not returned (UI section 5.6). A slot never changes availability (BR-11, AC-10).

Other query parameters are ignored. Errors: 422 `VALIDATION_FAILED` (`cakes` missing, not an integer, or out of range); 429 `RATE_LIMITED`; 503 `SERVICE_UNAVAILABLE`.

Field error of `cakes` [v1.9 | 2026-10-27]: confirmed as built (`AvailabilityService.cakesFieldName`, `cakesInvalidCode`, `AvailabilityRouteTests`): `fields` holds exactly one entry `{ "field": "cakes", "code": "CAKES_INVALID", "message_key": "ERR_SERVER" }`, the top-level `message_key` is `ERR_SERVER`, and the body has no `details`. The same entry is used for missing, non-numeric, below 1 and above the bound. `CAKES_INVALID` is a field-level code (it never appears as a top-level `code`); `ERR_SERVER` is right because the value comes from the client's own count, so a rejection is a client defect and the customer sees the generic error. A client that wants to show a better text has no key for it; none is planned. The name is kept (no rename): it describes the field, and `fields[].code` values are free-form per endpoint (`PHONE_INVALID` for orders).

Cache headers of errors [v1.9 | 2026-10-27]: only `200` carries `Cache-Control: no-store` on this endpoint. Error responses (422, 429, 503) carry no cache header, which is safe: RFC 9110 section 15.1 lists the heuristically cacheable status codes (200, 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501), and 422, 429, 503 are not among them, so a cache may not reuse them without explicit freshness. `404` gets `no-store` (section 4.6 and the mapper) because 404 is heuristically cacheable. `405` is also heuristically cacheable; the mapper does not add `no-store` to it today (the router answers 404, section 5, so only a handler-raised 405 would be affected): developer follow-up, add `no-store` to `METHOD_NOT_ALLOWED` too.

Side effects: none. Idempotency: safe. The list is advisory: `POST /v1/orders` re-checks (AC-9, AC-22).

Example: `GET /v1/availability?cakes=3` returns `{ "server_date": "2026-11-02", "dates": [ { "date": "2026-11-02", "available": false, "reason": "TOO_SOON" }, { "date": "2026-11-04", "available": true, "reason": null }, { "date": "2026-11-05", "available": false, "reason": "FULL" } ] }` (shortened).

### 4.3 POST /v1/orders

Role: anonymous. Purpose: confirm the order (FR-11). Header `Idempotency-Key` required (UUID v4, created by the client per confirmation attempt; ADR-0008). Headers `X-Platform`, `X-App-Version` required.

Request body:

| Field | Type | Required | Rules |
| ----- | ---- | -------- | ----- |
| items | array | yes | 1 to the number of active products (four at most today); no duplicate `product_id` [v1.6 \| 2026-10-26] |
| items[].product_id | uuid | yes | An active product |
| items[].quantity | integer | yes | 1 to `max_qty_per_cake`. Zero lines are not sent (AC-6) |
| delivery_date | date | yes | `YYYY-MM-DD`; rules checked in section "Order of checks" |
| slot_id | uuid | yes | An active slot |
| customer.name | string | yes | 1 to 100 code points after trim and NFC (ADR-0009) |
| customer.phone | string | yes | Any common writing of a Vietnamese mobile number; normalised per ADR-0009 (FR-13) |
| customer.address | string | yes | 1 to 250 |
| customer.district_id | uuid | yes | An active district (BR-3) |
| note | string or null | no | 0 to 200 (FR-18) |
| expected_total_vnd | integer | yes | The total shown on the review. Acknowledgement only (ADR-0010) |

Clients never send prices, fees, totals the server uses, or the order date. The server computes all of them.

Order of checks (first failure is returned; the capacity step is last and is the only step that takes a lock):

1. Rate limits (429), body size (413), required headers (400 `IDEMPOTENCY_KEY_REQUIRED`, `HEADER_INVALID`), `ORDERING_ENABLED` (503 `ORDERING_PAUSED`).
2. Schema and field validation (422 `VALIDATION_FAILED` with `fields[]`).
3. Idempotency lookup (replay 200, or 422 `IDEMPOTENCY_KEY_REUSED`).
4. Unknown or inactive product (409 `PRODUCT_UNAVAILABLE`, every offending `product_id` in `details`, nothing stored) [v1.8 | 2026-10-26], unknown or inactive slot (409 `SLOT_UNAVAILABLE`), district not served (422 `DISTRICT_UNSERVED`).
5. Total cakes below `min_qty` (422 `MIN_QTY`), date earlier than order date plus `lead_days` (422 `DATE_LEAD`), later than order date plus `max_days_ahead` (422 `DATE_HORIZON`). The order date is the current date in shop time (A-8).
6. Price acknowledgement: computed total differs from `expected_total_vnd` (409 `PRICE_CHANGED`).
7. Per-phone limit (429 `RATE_LIMITED`).
8. Capacity, then insert, in one transaction (409 `DATE_CAPACITY`).

201 response (created):

| Field | Type | Notes |
| ----- | ---- | ----- |
| order_code | string | `BT-` plus 6 characters (ADR-0009) |
| created_at | instant | |

Nothing else is returned: S-9 shows only the code and fixed text (FR-11, AC-15, AC-25). No status and no payment fields (FR-19).

200 response (replay): same body as the original 201, header `Idempotent-Replay: true` (AC-19).

Errors (see section 5): 400 `IDEMPOTENCY_KEY_REQUIRED`, `HEADER_INVALID`; 409 `DATE_CAPACITY`, `PRICE_CHANGED`, `PRODUCT_UNAVAILABLE`, `SLOT_UNAVAILABLE`; 413 `PAYLOAD_TOO_LARGE`; 422 `VALIDATION_FAILED`, `MIN_QTY`, `DATE_LEAD`, `DATE_HORIZON`, `DISTRICT_UNSERVED`, `IDEMPOTENCY_KEY_REUSED`; 429 `RATE_LIMITED`; 500 `INTERNAL_ERROR`; 503 `ORDERING_PAUSED`, `SERVICE_UNAVAILABLE`.

`PRICE_CHANGED` `details`: `{ "items": [ { "product_id": uuid, "price_vnd": int } ], "delivery_fee_vnd": int, "total_vnd": int }`. `MIN_QTY` `details`: `{ "min_qty": int }`. `DATE_LEAD` `details`: `{ "lead_days": int }`. `DATE_HORIZON` `details`: `{ "max_days_ahead": int }`. `DATE_CAPACITY` `details`: `{ "delivery_date": date }`. `PRODUCT_UNAVAILABLE` `details`: `{ "product_ids": [uuid] }`, all products of the request that are unknown or inactive, in request order [v1.8 | 2026-10-26]. The check runs before capacity, so no `customer_order`, item, `day_load` or `order_event` row is written and no idempotency record is kept; the same key may be sent again with changed content (hidden cake in a draft, ADR-0011; AC-34).

Side effects: one row in `customer_order`, one per item in `customer_order_item`, an increase of `day_load.cakes_accepted`, one `order_event` of type `created` (all in one transaction). No notification in this slice.

Idempotency: see ADR-0008. Same key and same normalised body returns the stored result (200). Same key and different body returns 422 `IDEMPOTENCY_KEY_REUSED`. Two simultaneous requests with the same key create one order. A key whose earlier attempt was rejected (no order exists) is processed again normally. The client keeps one key until the order content changes.

Example request:

```http
POST /v1/orders
Idempotency-Key: 5e0c2f6a-4c47-4a0e-9b6e-0f3a5d9c1a10
X-Platform: ios
X-App-Version: 1.0.0
Content-Type: application/json

{
  "items": [ { "product_id": "0b8f1f0e-1111-4a00-8000-000000000001", "quantity": 2 } ],
  "delivery_date": "2026-11-05",
  "slot_id": "0b8f1f0e-3333-4a00-8000-000000000001",
  "customer": { "name": "Nguyễn Văn A", "phone": "0900 000 000", "address": "1 Đường Số 5", "district_id": "0b8f1f0e-2222-4a00-8000-000000000001" },
  "note": null,
  "expected_total_vnd": 120000
}
```

Example response:

```json
{ "order_code": "BT-7K3M9Q", "created_at": "2026-11-02T03:15:09Z" }
```

### 4.4 GET /healthz

Role: anonymous. Shallow (default): returns 200 `{ "status": "ok" }` when the process runs, with no database query, so monitors never wake the free database. With `?deep=1`: also runs a trivial database query within 2 s; otherwise 503 `{ "status": "degraded" }` [v1.1 | 2026-10-25]. `Cache-Control: no-store`. No data about orders. The host health check and the uptime monitor use the shallow form only; the deep form is for the operator and deploy verification (deployment.md section 7) [v1.2 | 2026-10-26]. Rate limit group: reads.

### 4.5 GET /privacy

Role: anonymous. Returns the privacy statement as an HTML page (static file, text supplied by the owner, `backend/assets/privacy.html`). It states which data is collected (name, phone, address, note), why (to deliver and contact), who sees it (the shop), where it is stored (data location), and the retention period (open, BR-12). Needed for store listings (deployment.md section 4).

### 4.6 GET /assets/*

Static product images and the logo. Fake placeholder images only in the repository. Rules [v1.6 | 2026-10-26] (ADR-0017):

- One field name: the database column is `product.image_path` (relative path, for example `images/banana.png`, no leading slash, no `..`); the API field is `image_url`. The server builds `image_url` as the asset base plus `/assets/` plus `image_path`, plus the version query below. The asset base is empty (the path is relative to the API host) unless `PUBLIC_ASSET_BASE_URL` is set, then it is that prefix without a trailing slash. Clients resolve a relative `image_url` against the API base URL and use the value as given.
- Folder: files live in `backend/assets/images/` and are served at `/assets/images/*`. Nothing else under `backend/assets/` is served by this route (the privacy page is served by `/privacy`). A path with `..`, a backslash or a missing file answers 404 `NOT_FOUND`.
- Versioning: `image_url` ends with `?v=<first 8 hex characters of the SHA-256 of the file>`, computed by the server at start. A new photo (even under the same name) gets a new URL, so a long cache is safe. The static handler ignores the query. If the file is missing at start, the server logs a warning, omits `v`, and the URL answers 404.
- Cache headers: `200` for a file: `Cache-Control: public, max-age=31536000, immutable`. `404` and errors: `Cache-Control: no-store`. A `304` is not required (the URL changes with the content).

## 5. Error Catalogue

| Code | HTTP | Top-level `message_key` | Meaning | Client behaviour (UI key) |
| ---- | ---- | ----------------------- | ------- | ------------------------- |
| VALIDATION_FAILED | 422 | `ERR_SERVER` | One or more fields invalid; `fields[]` lists them | Show next to the field: `ERR_NAME_REQUIRED`, `ERR_PHONE_REQUIRED`, `ERR_PHONE_INVALID`, `ERR_ADDRESS_REQUIRED`, `ERR_DISTRICT_REQUIRED`, `ERR_NOTE_MAX`; return to S-7. Other field errors (lengths, tampering) show `ERR_SERVER` |
| MIN_QTY | 422 | `ERR_MIN_QTY` | Total cakes below `min_qty` | `ERR_MIN_QTY` with action to S-5 |
| DATE_LEAD | 422 | `ERR_DATE_LEAD` | Date too soon (also when midnight passed during the flow) | `ERR_DATE_LEAD`, action `ACTION_CHOOSE_DATE` |
| DATE_HORIZON | 422 | `ERR_DATE_HORIZON` | Date too far | `ERR_DATE_HORIZON`, action `ACTION_CHOOSE_DATE` |
| DATE_CAPACITY | 409 | `ERR_DATE_CAPACITY` | Date no longer holds the order (AC-9, AC-22) | `ERR_DATE_CAPACITY`, action `ACTION_CHOOSE_DATE` |
| DISTRICT_UNSERVED | 422 | `ERR_DISTRICT_UNSERVED` | District not served or inactive | `ERR_DISTRICT_UNSERVED`, action `ACTION_CHOOSE_DISTRICT` |
| PRICE_CHANGED | 409 | `MSG_PRICE_CHANGED` | Server total differs from `expected_total_vnd` (ADR-0010, Accepted) | Replace prices from `details`, return to the review, show `MSG_PRICE_CHANGED`, confirm enabled |
| PRODUCT_UNAVAILABLE | 409 | `ERR_PRODUCT_UNAVAILABLE` | A product is unknown or inactive; `details.product_ids` names them | Refresh the catalog, go to S-5 with `ERR_PRODUCT_UNAVAILABLE`; drop only the named items from the draft and keep all other data and a new idempotency key (ADR-0011) [v1.8 | 2026-10-26] |
| SLOT_UNAVAILABLE | 409 | `ERR_SLOT_UNAVAILABLE` | The slot is unknown or inactive | Refresh the catalog, go to S-6 with `ERR_SLOT_UNAVAILABLE` [v1.3 | 2026-10-26] |
| IDEMPOTENCY_KEY_REQUIRED | 400 | `ERR_SERVER` | Header missing | Client defect; show `ERR_SERVER` |
| HEADER_INVALID | 400 | `ERR_SERVER` | Header malformed | Client defect; `ERR_SERVER` |
| IDEMPOTENCY_KEY_REUSED | 422 | `ERR_SERVER` | Same key, different body | Client creates a new key and may retry once; else `ERR_SERVER` |
| RATE_LIMITED | 429 | `ERR_RATE_LIMITED` | Too many requests or orders for this phone | `ERR_RATE_LIMITED` (UI document v1.1), retry button stays enabled; show the message, offer retry after the `Retry-After` seconds [v1.3 | 2026-10-26] |
| PAYLOAD_TOO_LARGE | 413 | `ERR_SERVER` | Body over 8 KB | `ERR_SERVER` (client defect) |
| ORDERING_PAUSED | 503 | `ERR_SERVER` | The owner paused ordering | `ERR_SERVER` (the customer can call the shop) |
| SERVICE_UNAVAILABLE | 503 | `ERR_SERVER` | Database unavailable | `ERR_SERVER` with retry; same key on retry |
| INTERNAL_ERROR | 500 | `ERR_SERVER` | Unexpected error | `ERR_SERVER` with retry; same key on retry |
| NOT_FOUND | 404 | `ERR_SERVER` | No route for the method and path pair, including a known path with an unrouted method (Vapor matches method and path together, so `POST /healthz` is a miss; routing error, not raised by a business rule) | Client defect; `ERR_SERVER`, treated like `INTERNAL_ERROR` (retry is pointless but harmless) [v1.3 | 2026-10-26] [v1.5 | 2026-10-26] |
| METHOD_NOT_ALLOWED | 405 | `ERR_SERVER` | Only when the framework or a handler itself reports 405; the router does not (see the `NOT_FOUND` row) | Same as `NOT_FOUND` [v1.5 | 2026-10-26] |
| (no response) | n/a | No connection | `ERR_OFFLINE` with retry; same key |
| (client timeout 10 s) | n/a | Unknown outcome | `ERR_TIMEOUT` with retry; same key, so a repeat returns the stored order (AC-19) |

All 5xx and network failures keep all entered data (FR-17).

Rules of the catalogue [v1.3 | 2026-10-26]:

- The top-level `message_key` is `ERR_` plus the code for the codes the UI document shows by name (`MIN_QTY`, `DATE_LEAD`, `DATE_HORIZON`, `DATE_CAPACITY`, `DISTRICT_UNSERVED`, `PRODUCT_UNAVAILABLE`, `SLOT_UNAVAILABLE`, `RATE_LIMITED`), `MSG_PRICE_CHANGED` for `PRICE_CHANGED`, and `ERR_SERVER` for every other code. `VALIDATION_FAILED` has no single text: the app reads `fields[].message_key`; the top-level `ERR_SERVER` applies when `fields` is missing, empty or holds only keys the app does not know.
- Unknown error codes: the client shows `ERR_SERVER`.
- Field-level codes [v1.9 | 2026-10-27]: `fields[].code` values (for example `PHONE_INVALID`, `CAKES_INVALID`) are not in the table above; they are specific to the field and endpoint, and the client reads `fields[].message_key`, not the code.
- Naming note [v1.9 | 2026-10-27]: the backend error type `CatalogRepositoryError` is also thrown by the availability repository; the name is catalogue-flavoured. A shared rename (or folding into a Vapor-free `DomainError`) is planned with architecture.md section 14.1; it has no effect on this contract.
- `RATE_LIMITED` carries the `Retry-After` header (seconds, an integer) and `details.retry_after_seconds` with the same value; the default is 60 seconds (the shortest window, the per-minute read limit, in the rate-limit table at the top) when the limiter gives no value [v1.4 | 2026-10-26].
- Wrong method [v1.5 | 2026-10-26]: clients never send a method other than the one documented per endpoint. Any unrouted method and path pair answers `404 NOT_FOUND` (a `HEAD` on a routed `GET` path is not unrouted: it answers like `GET`, section 4.1) [v1.7 | 2026-10-26]; the API does not promise `405`. The 405 mapping stays in the error middleware only for a 405 that the framework or a handler raises, and clients treat both alike.
- Framework errors never leave as framework bodies: the error middleware maps a Vapor `AbortError` by status (404 `NOT_FOUND`, 405 `METHOD_NOT_ALLOWED`, 413 `PAYLOAD_TOO_LARGE`, 429 `RATE_LIMITED`, 503 `SERVICE_UNAVAILABLE`, other 4xx `VALIDATION_FAILED` without `fields`, everything else `INTERNAL_ERROR`). A decoding failure of a body is therefore `VALIDATION_FAILED` without `fields`.
- Database outage: `SERVICE_UNAVAILABLE` is answered only when a repository throws `APIError(.serviceUnavailable)`. The mapper does not read driver errors (they can hold SQL or customer data), so an unwrapped driver error becomes `INTERNAL_ERROR`. Every repository method that talks to the database must catch connection and pool errors and rethrow them as `APIError(.serviceUnavailable)` (slice 3 for orders; slice 1 for catalog and availability). Both codes are retryable with the same key.

## 6. Compatibility Policy

- Inside `v1`: additive only (new optional request fields, new response fields, new error codes, new enum values for `reason`). Clients ignore unknown response fields and treat unknown error codes as `INTERNAL_ERROR` behaviour.
- A breaking change creates `/v2` and keeps `/v1` until the store statistics show old app versions are gone (a rule of thumb: at least 90 days after the new app release, unverified).
- `X-App-Version` and `X-Platform` are logged to see which versions call the API.
- The price acknowledgement field (`expected_total_vnd`) and `PRICE_CHANGED` are final (ADR-0010 Accepted) [v1.1 | 2026-10-25].
- Staff endpoints will live under `/v1/staff` and need new documents sections; they will not change the customer endpoints.

## 7. Traceability check

Every endpoint above is in the index with FRs. Every data field used traces to data-model.md: catalog fields to `shop`, `shop_setting`, `product`, `district`, `delivery_slot`; order fields to `customer_order` and `customer_order_item`; availability to `day_load` and `shop_setting`.

## 8. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| API-Q1 | Message keys for `PRODUCT_UNAVAILABLE`, `SLOT_UNAVAILABLE`, `RATE_LIMITED` | Client text by code | No | technical | Closed 2026-10-26: UI document v1.1 defines all three; table in section 5 lists the key per code | atlas-architect |
| API-Q2 | Price-change behaviour (ADR-0010) | `expected_total_vnd`, `PRICE_CHANGED` | No | business | Closed: owner accepted option A (2026-10-25) | Owner |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-25 | ADR-0010 accepted; Vapor implementation notes; shallow and deep health check; trial-host timeout note. |
| 1.2 | 2026-10-26 | Health check consumers clarified (shallow for monitors, deep for operator and deploy checks). |
| 1.3 | 2026-10-26 | Error catalogue: top-level `message_key` per code, `NOT_FOUND` and `METHOD_NOT_ALLOWED`, `RATE_LIMITED` key and `Retry-After`, framework error mapping, database outage wrapping rule; API-Q1 closed. |
| 1.4 | 2026-10-26 | Body limit boundary stated (8 KB passes, one byte more fails); `Retry-After` default 60 s. |
| 1.5 | 2026-10-26 | D-9: unrouted method and path pair answers 404 `NOT_FOUND`; 405 kept only when raised by the framework or a handler. |
| 1.6 | 2026-10-26 | QA document findings (DOC-1 to DOC-7, DOC-10) and owner decision on the catalog: every active cake is listed (zero active is the only error case); one image field rule and asset versioning; strong ETag with weak `If-None-Match` comparison; one shared read budget with `Retry-After` rule; unknown query parameters ignored; `note_max_length` is a constant; sample wording removed from examples. ADR-0017. |
| 1.7 | 2026-10-26 | DOC-11: `HEAD` answers like `GET` and counts; D-18: per-address window, 10,000-address bound, only `GET`/`HEAD` counted, 429 not counted; D-20: ETag wording; client address rule with one proxy. |
| 1.8 | 2026-10-26 | UI TQ-9, TQ-10: `PRODUCT_UNAVAILABLE` `details.product_ids`, nothing stored; catalog refresh counted against the read budget (ADR-0011). |
| 1.9 | 2026-10-27 | Slice 2 gaps: `cakes` field error confirmed (`CAKES_INVALID`, `ERR_SERVER`), zero active products makes every `cakes` a 422, error responses carry no cache header except 404 (RFC 9110 15.1), field-level codes and the repository error name noted. Client address rule points to ADR-0019. (Version 1.8 above was UI TQ-9 and TQ-10.) |
