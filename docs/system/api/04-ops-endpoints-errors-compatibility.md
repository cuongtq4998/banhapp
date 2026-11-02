# API Specification: Health, privacy, assets, error catalogue, compatibility, traceability

Part of [api.md](../api.md) (index, version, change log), sections 4.4 to 4.6, 5, 6, 7. Moved from api.md v1.9 with the wording unchanged unless a line carries a newer label [v1.10 | 2026-10-27].

## 4. Endpoint Specs (continued)

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
| VALIDATION_FAILED | 422 | `ERR_SERVER` | One or more fields invalid; `fields[]` lists them | Show next to the field: `ERR_NAME_REQUIRED`, `ERR_PHONE_REQUIRED`, `ERR_PHONE_INVALID`, `ERR_ADDRESS_REQUIRED`, `ERR_DISTRICT_REQUIRED`, `ERR_NOTE_MAX`; return to S-7. Other field errors (lengths, tampering) show `ERR_SERVER`; codes and paths in "Field-level codes" below [v1.12 | 2026-10-29] |
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
- Naming note [v1.9 | 2026-10-27]: the backend error type `CatalogRepositoryError` is also thrown by the availability repository; the name is catalogue-flavoured. A shared rename (or folding into a Vapor-free `DomainError`) is a developer task under architecture.md section 14.1 and ADR-0018 [v1.10 | 2026-10-27]; it has no effect on this contract.
- `RATE_LIMITED` carries the `Retry-After` header (seconds, an integer) and `details.retry_after_seconds` with the same value; the default is 60 seconds (the shortest window, the per-minute read limit, in the rate-limit table at the top) when the limiter gives no value [v1.4 | 2026-10-26].
- Wrong method [v1.5 | 2026-10-26]: clients never send a method other than the one documented per endpoint. Any unrouted method and path pair answers `404 NOT_FOUND` (a `HEAD` on a routed `GET` path is not unrouted: it answers like `GET`, section 4.1) [v1.7 | 2026-10-26]; the API does not promise `405`. The 405 mapping stays in the error middleware only for a 405 that the framework or a handler raises, and clients treat both alike.
### Field-level codes of `VALIDATION_FAILED` on `POST /v1/orders` [v1.12 | 2026-10-29]

Each `fields[]` entry is `{ "field", "code", "message_key" }`. `field` is a path: `items`, `items[0].quantity`, `items[1].product_id`, `delivery_date`, `slot_id`, `customer`, `customer.name`, `customer.phone`, `customer.address`, `customer.district_id`, `note`, `expected_total_vnd`. Entries come in this order: items (in array order), `delivery_date`, `slot_id`, `customer` (name, phone, address, district), `note`, `expected_total_vnd`. Every problem found is listed (the parser does not stop at the first), unknown keys included. Built in `OrderFieldErrors.swift`, fixture `order-error-validation-failed.json`.

| Code | Field | `message_key` | When |
| ---- | ----- | ------------- | ---- |
| NAME_REQUIRED | `customer.name` | `ERR_NAME_REQUIRED` | Missing, null, blank after trim |
| PHONE_REQUIRED | `customer.phone` | `ERR_PHONE_REQUIRED` | Missing, null, blank |
| PHONE_INVALID | `customer.phone` | `ERR_PHONE_INVALID` | Not a string, or not a Vietnamese mobile number after normalisation (ADR-0009) |
| ADDRESS_REQUIRED | `customer.address` | `ERR_ADDRESS_REQUIRED` | Missing, null, blank |
| DISTRICT_REQUIRED | `customer.district_id` | `ERR_DISTRICT_REQUIRED` | Missing or null |
| NOTE_TOO_LONG | `note` | `ERR_NOTE_MAX` | Over 200 code points |
| NAME_INVALID, ADDRESS_INVALID | `customer.name`, `customer.address` | `ERR_SERVER` | Wrong type, too long, forbidden control characters |
| DISTRICT_INVALID, SLOT_INVALID, PRODUCT_INVALID | `customer.district_id`, `slot_id`, `items[i].product_id` | `ERR_SERVER` | Not a UUID string |
| NOTE_INVALID | `note` | `ERR_SERVER` | Not a string or null, or forbidden characters |
| ITEMS_INVALID | `items` or `items[i]` | `ERR_SERVER` | Not an array, empty, or an element that is not an object |
| PRODUCT_DUPLICATE | `items[i].product_id` | `ERR_SERVER` | Product repeated (reported on the later line) |
| QUANTITY_INVALID | `items[i].quantity` | `ERR_SERVER` | Not an integer, below 1, or above `max_qty_per_cake` (hard parser bound, then the shop setting) |
| DELIVERY_DATE_INVALID | `delivery_date` | `ERR_SERVER` | Not a real `YYYY-MM-DD` day |
| CUSTOMER_INVALID | `customer` | `ERR_SERVER` | Not an object (its subfields are then not checked) |
| EXPECTED_TOTAL_INVALID | `expected_total_vnd` | `ERR_SERVER` | Not an integer, or negative |
| FIELD_UNKNOWN | the unknown key (`customer.x`, `items[i].x`, `x`) | `ERR_SERVER` | Key not in the contract, listed in sorted order |

A body that is not JSON, or not an object, is `VALIDATION_FAILED` without `fields`. There is no rule "items count at most active products" (removed [v1.12 | 2026-10-29]): a cart with a hidden cake must reach step 4 and answer `PRODUCT_UNAVAILABLE` (AC-34).

- Framework errors never leave as framework bodies: the error middleware maps a Vapor `AbortError` by status (404 `NOT_FOUND`, 405 `METHOD_NOT_ALLOWED`, 413 `PAYLOAD_TOO_LARGE`, 429 `RATE_LIMITED`, 503 `SERVICE_UNAVAILABLE`, other 4xx `VALIDATION_FAILED` without `fields`, everything else `INTERNAL_ERROR`). A decoding failure of a body is therefore `VALIDATION_FAILED` without `fields`.
- Database outage: `SERVICE_UNAVAILABLE` is answered only when a repository throws `APIError(.serviceUnavailable)`. The mapper does not read driver errors (they can hold SQL or customer data), so an unwrapped driver error becomes `INTERNAL_ERROR`. Every repository method that talks to the database must catch connection and pool errors and rethrow them as `APIError(.serviceUnavailable)` (slice 3 for orders; slice 1 for catalog and availability). Both codes are retryable with the same key.

## 6. Compatibility Policy

- Inside `v1`: additive only (new optional request fields, new response fields, new error codes, new enum values for `reason`). Clients ignore unknown response fields and treat unknown error codes as `INTERNAL_ERROR` behaviour.
- A breaking change creates `/v2` and keeps `/v1` until the store statistics show old app versions are gone (a rule of thumb: at least 90 days after the new app release, unverified).
- `X-App-Version` and `X-Platform` are logged to see which versions call the API. On `POST /v1/orders` `X-App-Version` must be `N.N.N`: three groups of 1 to 5 digits (no `v`, no suffix like `-beta`); `X-Platform` must be `ios` or `android`; a missing, repeated or other form answers 400 `HEADER_INVALID` (same pattern as the access log) [v1.12 | 2026-10-29].
- The price acknowledgement field (`expected_total_vnd`) and `PRICE_CHANGED` are final (ADR-0010 Accepted) [v1.1 | 2026-10-25].
- Admin endpoints live under `/v1/auth`, `/v1/admin` and `/v1/owner` (api/05 to api/08); they do not change the customer endpoints except as listed in the v1.13 change log [v1.13 | 2026-10-31].

## 7. Traceability check

Every endpoint above is in the index with FRs. Every data field used traces to data-model.md: catalog fields to `shop`, `shop_setting`, `product`, `district`, `delivery_slot`; order fields to `customer_order` and `customer_order_item`; availability to `day_load` and `shop_setting`.
