# API Specification: customer order lookup by phone

Part of [api.md](../api.md), section 10.14 (new). Version 1.1 [v1.1 | 2026-11-02]. Traces: FR-22 to FR-27 (place-order 08), BR-16 to BR-18, AC-38 to AC-47, FR-28 to FR-30; ADR-0034, ADR-0017, ADR-0019. No sign-in, no push to customers.

## 10.14.1 POST /v1/orders/lookup

POST so the phone is never in a URL or an access log. Body (8 KB limit, api/01): `{ "phone": "+84900000001", "cursor"?: "<opaque>" }`. The phone is normalised like `POST /v1/orders` (ADR-0009: trim, spaces and dots removed, `0` prefix to `+84`, E.164 pattern). Optional header `X-Installation-Id` (format as api/05, never required, spoofable).

200 body:

```json
{ "orders": [ { "order_code": "BA-000000", "status": "DeliveryStarted",
  "placed_at": "2026-11-01T03:00:00Z", "phone_masked": "+84 900 000 ***",
  "district_name": "District 1", "requested_delivery_date": "2026-11-05",
  "slot_start_time": "14:00", "slot_end_time": "16:00", "expected_delivery_date": "2026-11-06",
  "items": [ { "cake_name": "Plain cake", "quantity": 2, "unit_price_vnd": 120000 } ],
  "items_subtotal_vnd": 240000, "delivery_fee_estimate_vnd": 20000,
  "delivery_fee_final_vnd": 25000, "amount_to_collect_vnd": 265000 } ],
  "next_cursor": null, "as_of": "2026-11-02T03:00:00Z" }
```

`status` is one of the six names; the legacy words are never sent. The shop contact comes from the catalog (`phone_contact`, `zalo_contact`), not from this answer. `delivery_fee_final_vnd` and `amount_to_collect_vnd` are null until entered; after a fee correction only the latest value is sent. `expected_delivery_date` is null until set. A `Cancelled` order carries `status` and the fields above only: no reason, no actor, no event or date-change history, no corrections.

## 10.14.2 Never sent

Street address, ward, note, customer name, `cancel_reason`, staff names or ids, account data, `day_load`, internal ids (`id`), event rows, date-change and fee-correction rows, `is_sample`, the full phone.

## 10.14.3 Masking, window, order, paging

- Masking: the last 3 digits are replaced by `*` and the digits are grouped (`+84 900 000 ***`); the number is the caller's own input, so nothing new is revealed.
- Window: status in the open four at any age, or `Finished`, `Cancelled` with `status_changed_at` within 30 days (value is configuration `LOOKUP_RETENTION_DAYS`, default 30). Purged rows never match.
- Order: `placed_at` descending, then `id`. Page size 10 (configuration `LOOKUP_PAGE_SIZE`); at most 5 pages: the fifth page always has `next_cursor` null, so one phone yields at most 50 orders per lookup session.
- Cursor: opaque, holds the last `(placed_at, id)` and a keyed hash of the normalised phone; used with another phone, malformed or tampered: 422 `VALIDATION_FAILED` field `CURSOR_INVALID`.

## 10.14.4 Same shape, timing, no enumeration

A phone with no orders, a purged phone and an unused number all return 200 `{ "orders": [], "next_cursor": null, "as_of": ... }` (same headers, same field set). Both paths run the same indexed query and mapping; the handler waits until a minimum duration (`LOOKUP_MIN_RESPONSE_MS`, default 250) has passed before answering, so the empty and non-empty cases are not told apart by time within normal load. The floor is measured from request start and must stay above the p99 of the indexed query (`LIMIT 11`, same SQL and mapping on both paths) [v1.1 | 2026-11-02]; deployment.md records the measured p99 and the counter `lookup_floor_exceeded` (no phone) alerts when an answer was slower than the floor, because only then time leaks. Residual: under load above the floor, a non-empty answer can be slower (accepted, ADR-0034). Rate-limit counters ignore whether orders exist. Only a malformed phone differs (422), which says nothing about the number being in use.

## 10.14.5 Rate limits (fixed windows, in-memory, numbers are configuration)

| Key | Default | Notes |
| --- | ------- | ----- |
| Normalised phone (keyed hash, never the digits) | 10 lookups per hour | Every request without a cursor counts (empty or not); a request with a valid cursor does not count here [v1.1 | 2026-11-02]: it proves a first page was already counted for that phone (cursor bound by keyed hash), and 5 pages would otherwise use half the budget. It counts against the address and installation limits |
| Client address (ADR-0019 model) | 30 lookups per hour | Distributed guessers pass; watch 429 volume |
| Installation id, if sent | 20 per hour | Cosmetic: a caller can omit or change it; address and phone limits carry the protection |

Client address [v1.1 | 2026-11-02]: config `CLIENT_ADDRESS_HEADER` (empty by default: use the socket peer address) names the one header set by the platform proxy, and `TRUSTED_PROXY_HOPS` (default 1) says how many entries from the right belong to trusted proxies. Only that header is read; any client-supplied `X-Forwarded-For` or similar value to the left of the trusted hops is ignored, never used as a key. A wrong setting makes all callers share one address; deployment.md checks it after each deploy. The rule applies to every limiter (ADR-0019).

Excess: 429 `RATE_LIMITED` with `Retry-After` (whole seconds, at least 1, at most 3600); the body does not say which key tripped and is the same whether the phone has orders or not. A 429 does not count. Limits run before the database query. Restart clears the counters (accepted, as ADR-0017). Side effect: someone can use up a victim's per-phone budget (ADR-0034 consequences).

## 10.14.6 Errors

| Status | Code | When |
| ------ | ---- | ---- |
| 422 | `VALIDATION_FAILED` | `fields[]`: `PHONE_REQUIRED`, `PHONE_INVALID`, `CURSOR_INVALID`, `FIELD_UNKNOWN` |
| 413 | `PAYLOAD_TOO_LARGE` | body 8 KB or more |
| 429 | `RATE_LIMITED` | 10.14.5 |
| 503 | `SERVICE_UNAVAILABLE` | database down (api/04) |

No 404 and no 401 exist on this route.

## 10.14.7 Headers, privacy, logging

Response: `Cache-Control: no-store`, `Content-Type: application/json`, no `ETag`, no CDN caching (personal data). Logs hold method, route template, status, duration and the limiter decision only: never the body, the phone, the cursor, order codes of the answer or the installation id (extends data-model/03 server log rule). Limiter keys are keyed hashes (secret `LOOKUP_KEY_SECRET`, name only in `.env.example`, rotated by deployment.md procedure). Monitoring counts 429 by key type, not by value. Customer apps do not store the answer beyond the last read for the offline view (FR-26) and show it with its `as_of` time [v1.1 | 2026-11-02]: `as_of` (server time of the read) is enough; the app stores it with the answer and shows that value, never the device clock. The app may check 9 to 11 digits before calling as a hint only (the server 422 `PHONE_INVALID` decides; an invalid number is never sent, so it costs no limit). The app adds no artificial wait: the 250 ms floor is the server's; the spinner shows while the request runs.

## 10.14.8 Fixtures (forge-dev, `contracts/fixtures/customer/`)

`order-lookup-request.json` (fake phone in the `+84900000000` to `+84900000099` range), `order-lookup-answer-open.json`, `order-lookup-answer-cancelled.json`, `order-lookup-answer-empty.json`, `error-lookup-rate-limited.json`, `error-lookup-phone-invalid.json`, `error-lookup-cursor-invalid.json`.

## 10.14.9 Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.1 | 2026-11-02 | Cursor pages not counted per phone, client address rule, timing floor above p99, as_of, client digit hint. |
| 1.0 | 2026-11-02 | First version (ADR-0034). |
