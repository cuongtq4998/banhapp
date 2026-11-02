# API Specification: customer order lookup by phone

Part of [api.md](../api.md), section 10.14 (new). Version 1.4 [v1.4 | 2026-11-02]. Traces: FR-22 to FR-27 (place-order 08), BR-16 to BR-18, AC-38 to AC-47, FR-28 to FR-30; ADR-0034, ADR-0017, ADR-0019. No sign-in, no push to customers.

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

Per order the list carries the order code and the cake lines (`items[]`: `cake_name` as stored at order time, `quantity`, `unit_price_vnd`, sorted by `cake_name` then product id) [v1.2 | 2026-11-02]; nothing else about the customer. `status` is one of the six names; the legacy words are never sent. The shop contact comes from the catalog (`phone_contact`, `zalo_contact`), not from this answer. `delivery_fee_final_vnd` and `amount_to_collect_vnd` are null until entered; after a fee correction only the latest value is sent. Amount rule [v1.3 | 2026-11-02] (one rule, same in api/09 admin detail): `amount_to_collect_vnd = items_subtotal_vnd + delivery_fee_final_vnd` when `delivery_fee_final_vnd` is not null (a final fee of 0 gives the subtotal), else null. The estimate is never part of it: before the real fee is known the customer sees the items subtotal and `delivery_fee_estimate_vnd` as an estimate only, and the apps show no amount to collect (query to canvas-ui: wording "fee to be confirmed" instead of a total). `expected_delivery_date` is null until set. A `Cancelled` order carries `status` and the fields above only: no reason, no actor, no event or date-change history, no corrections.

## 10.14.2 Never sent

Street address, ward, note, customer name, product ids and image paths of the items, `cancel_reason`, staff names or ids, account data, `day_load`, internal ids (`id`), event rows, date-change and fee-correction rows, `is_sample`, the full phone.

## 10.14.3 Masking, window, order, paging

- Personal data in the answer [v1.2 | 2026-11-02]: the order code and the cake names with quantities are new exposure (owner decision of 2026-11-02, ADR-0034 v1.2): anyone who knows the number sees what that phone bought. Not sent: full phone, street address, ward, note, name, cancel reason, staff names. Fields of one order are decided by one mapper `LookupOrderView`; a field not in it cannot leak.
- Masking: the last 3 digits are replaced by `*` and the digits are grouped (`+84 900 000 ***`); the number is the caller's own input, so nothing new is revealed.
- Window: status in the open four at any age, or `Finished`, `Cancelled` with `status_changed_at` within 30 x 24 hours (internal rule, configuration `LOOKUP_RETENTION_DAYS`, default 30). The edge is inclusive [v1.3 | 2026-11-02], like the 90-day rule: predicate `status NOT IN ('Finished','Cancelled') OR status_changed_at >= now() - retention` with `now` read once per request (the same `as_of`); an order at exactly 30 x 24 h is shown, one microsecond older is absent. Purged rows never match [v1.2 | 2026-11-02].
- The client is never told the number of days: no field, header, error or text of the answer holds it, and an order past the window is simply absent (same as an unknown order). The apps show no retention sentence (query to canvas-ui: `T_FINISHED_NOTE_30`).
- Items query [v1.2 | 2026-11-02]: `customer_order_item` (PK `(order_id, product_id)`, so `order_id` is an index prefix) holds `product_name`, `quantity`, `unit_price_vnd`; no new table, column or index. The items come in the same statement as the page, no second round trip: the page query (`LIMIT 11`, index `(customer_phone, created_at)`) does `LEFT JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('cake_name', product_name, 'quantity', quantity, 'unit_price_vnd', unit_price_vnd) ORDER BY product_name, product_id) FROM customer_order_item WHERE order_id = o.id)`. At most 11 orders x a handful of lines; the same SQL runs for empty and non-empty phones (10.14.4).
- Order: `placed_at` descending, then `id`. Page size 10; at most 5 pages (both constants of `LookupPolicy`, not environment settings [v1.4 | 2026-11-02]): the fifth page always has `next_cursor` null, so one phone yields at most 50 orders per lookup session.
- Cursor [v1.4 | 2026-11-02], format as built (not the admin list cursor of api/06): base64 (standard alphabet) of the UTF-8 text `micros|id|page|tag`, where `micros` is the placed time, `id` the order UUID, `page` the number of the page the cursor opens (2 to 5) and `tag` the keyed hash (HMAC-SHA256, `LOOKUP_KEY_SECRET`) of `phone|micros|id|page`. It has no version number: a change of format later is made by making old cursors fail with `CURSOR_INVALID`, and the client restarts at the first page (the same effect as a restart, 10.14.7). A marker is not wanted: cursors live minutes, are never stored, and the client already handles `CURSOR_INVALID`. The cursor holds the last `(placed_at, id)`, with `placed_at` as an integer count of microseconds since the Unix epoch (64-bit integer, never a floating number or a date string with fewer digits) [v1.3 | 2026-11-02]: equal `created_at` values at microsecond precision must compare exactly as the database does, and the row test is `(created_at, id) < (cursor_time, cursor_id)` with the time rebuilt from those microseconds. A floating-point seconds value loses sub-microsecond exactness and can repeat or skip a row. Cursor content and a keyed hash of the normalised phone; used with another phone, malformed or tampered: 422 `VALIDATION_FAILED` field `CURSOR_INVALID`.

## 10.14.4 Same shape, timing, no enumeration

A phone with no orders, a purged phone and an unused number all return 200 `{ "orders": [], "next_cursor": null, "as_of": ... }` (same headers, same field set). Both paths run the same indexed query and mapping; the handler waits until a minimum duration (`LOOKUP_FLOOR_MS`, default 250; 0 allowed, as in tests) has passed before answering, so the empty and non-empty cases are not told apart by time within normal load. The floor is measured from request start and must stay above the p99 of the indexed query (`LIMIT 11`, same SQL and mapping on both paths) [v1.1 | 2026-11-02]; deployment/03 section 7.1 records the measured p99 and the sink of `lookup_floor_exceeded` (a warning log line without any phone, plus an in-process count that is not exposed on any route) [v1.3 | 2026-11-02]; it alerts when answers were slower than the floor, because only then time leaks. Residual: under load above the floor, a non-empty answer can be slower (accepted, ADR-0034). Rate-limit counters ignore whether orders exist. Only a malformed phone differs (422), which says nothing about the number being in use.

## 10.14.5 Rate limits (fixed windows, in-memory, numbers are constants)

| Key | Default | Notes |
| --- | ------- | ----- |
| Normalised phone (keyed hash, never the digits) | 10 lookups per hour | Every request without a cursor counts (empty or not); a request with a valid cursor does not count here [v1.1 | 2026-11-02]: it proves a first page was already counted for that phone (cursor bound by keyed hash), and 5 pages would otherwise use half the budget. It counts against the address and installation limits |
| Client address (ADR-0019 model) | 30 lookups per hour | Distributed guessers pass; watch 429 volume |
| Installation id, if sent | 20 per hour | Cosmetic: a caller can omit or change it; address and phone limits carry the protection |

Settings [v1.4 | 2026-11-02]: the numbers above, the page size 10, the page cap 5 and the one-hour window are constants of `LookupPolicy`; changing one is a code change with review, which is the point for security limits and avoids drift between hosts. The environment settings are exactly five: `LOOKUP_KEY_SECRET`, `LOOKUP_RETENTION_DAYS` (default 30, positive integer), `LOOKUP_FLOOR_MS` (default 250, 0 or more), `CLIENT_ADDRESS_HEADER`, `TRUSTED_PROXY_HOPS` (default 1, positive). A malformed number keeps the default. `LOOKUP_KEY_SECRET` unset: the process makes a random secret at start [v1.4 | 2026-11-02]. Effect: after a restart every cursor issued before fails with 422 `CURSOR_INVALID` (acceptable: the client reloads page 1), and with two instances a cursor from one fails on the other. Deployment rule: set the same secret in the host for every instance (deployment.md); a rotation has the same effect as a restart.

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

`order-lookup-request.json` (fake phone in the `+84900000000` to `+84900000099` range), `order-lookup-answer-open.json`, `order-lookup-answer-cancelled.json`, `order-lookup-answer-empty.json` (the open and cancelled answers carry `order_code` and `items[]` with two fake cake lines; the cancelled one keeps its items and still has no reason), `error-lookup-rate-limited.json`, `error-lookup-phone-invalid.json`, `error-lookup-cursor-invalid.json`.

## 10.14.9 Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.4 | 2026-11-02 | Truth about the built code: `LOOKUP_FLOOR_MS`; page size, page cap and budgets are constants, five environment settings listed; cursor format as built, no version marker; unset secret behaviour. |
| 1.3 | 2026-11-02 | Inclusive window edge and predicate, one amount-to-collect rule, cursor time as integer microseconds, floor-exceeded sink. |
| 1.2 | 2026-11-02 | Order code and cake lines in the list (owner decision), items query without extra round trip, retention days never sent to the client, fixtures. |
| 1.1 | 2026-11-02 | Cursor pages not counted per phone, client address rule, timing floor above p99, as_of, client digit hint. |
| 1.0 | 2026-11-02 | First version (ADR-0034). |
