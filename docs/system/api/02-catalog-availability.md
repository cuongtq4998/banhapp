# API Specification: GET /v1/catalog and GET /v1/availability

Part of [api.md](../api.md) (index, version, change log), sections 4.1, 4.2. Moved from api.md v1.9 with the wording unchanged unless a line carries a newer label [v1.10 | 2026-10-27].

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
