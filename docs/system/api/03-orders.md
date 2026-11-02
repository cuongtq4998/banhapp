# API Specification: POST /v1/orders

Part of [api.md](../api.md) (index, version, change log), sections 4.3. Moved from api.md v1.9 with the wording unchanged unless a line carries a newer label [v1.10 | 2026-10-27].

## 4. Endpoint Specs (continued)

### 4.3 POST /v1/orders

Role: anonymous. Purpose: confirm the order (FR-11). Header `Idempotency-Key` required (UUID v4, created by the client per confirmation attempt; ADR-0008). Headers `X-Platform` (`ios` or `android`), `X-App-Version` (`N.N.N` digits only) required; otherwise 400 `HEADER_INVALID` [v1.12 | 2026-10-29].

Request body:

| Field | Type | Required | Rules |
| ----- | ---- | -------- | ----- |
| items | array | yes | At least 1; no duplicate `product_id`. No upper bound on the line count is checked: a line for a hidden or unknown product is `PRODUCT_UNAVAILABLE`, not a validation error (AC-34) [v1.12 \| 2026-10-29] |
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

1. Per-address rate limit (429; a global middleware, so it runs before the body is read and a replay counts; a 429 does not count) [v1.12 | 2026-10-29], body size (413), required headers (400 `IDEMPOTENCY_KEY_REQUIRED`, `HEADER_INVALID`), `ORDERING_ENABLED` (503 `ORDERING_PAUSED`).
2. Schema and field validation (422 `VALIDATION_FAILED` with `fields[]`).
3. Idempotency lookup (replay 200, or 422 `IDEMPOTENCY_KEY_REUSED`).
4. Unknown or inactive product (409 `PRODUCT_UNAVAILABLE`, every offending `product_id` in `details`, nothing stored) [v1.8 | 2026-10-26], unknown or inactive slot (409 `SLOT_UNAVAILABLE`), district not served (422 `DISTRICT_UNSERVED`).
5. Total cakes below `min_qty` (422 `MIN_QTY`), date earlier than order date plus `lead_days` (422 `DATE_LEAD`), later than order date plus `max_days_ahead` (422 `DATE_HORIZON`). The order date is the current date in shop time (A-8).
6. Price acknowledgement: computed total differs from `expected_total_vnd` (409 `PRICE_CHANGED`).
7. Per-phone limit (429 `RATE_LIMITED`, `Retry-After` 3600): counted orders for the normalised phone in the last 24 hours, at least 5; an order counts unless it is `Cancelled`, but one cancelled with reason `fake_spam` keeps counting (FR-27, ADR-0030) [v1.13 | 2026-10-31]. Check, then insert: a burst of simultaneous orders on one phone can slip a few past the limit; capacity stays exact (step 8).
8. Capacity, then insert, in one transaction (409 `DATE_CAPACITY`).

201 response (created):

| Field | Type | Notes |
| ----- | ---- | ----- |
| order_code | string | `BT-` plus 6 characters (ADR-0009) |
| created_at | instant | |

Nothing else is returned: S-9 shows only the code and fixed text (FR-11, AC-15, AC-25). No status and no payment fields (FR-19).

200 response (replay): same body as the original 201, byte for byte (JSON keys are sorted), header `Idempotent-Replay: true` (AC-19). A replay passes the per-address limit and counts against it [v1.12 | 2026-10-29]; it is never counted by the per-phone limit, because no order is stored.

Errors (see section 5): 400 `IDEMPOTENCY_KEY_REQUIRED`, `HEADER_INVALID`; 409 `DATE_CAPACITY`, `PRICE_CHANGED`, `PRODUCT_UNAVAILABLE`, `SLOT_UNAVAILABLE`; 413 `PAYLOAD_TOO_LARGE`; 422 `VALIDATION_FAILED`, `MIN_QTY`, `DATE_LEAD`, `DATE_HORIZON`, `DISTRICT_UNSERVED`, `IDEMPOTENCY_KEY_REUSED`; 429 `RATE_LIMITED`; 500 `INTERNAL_ERROR`; 503 `ORDERING_PAUSED`, `SERVICE_UNAVAILABLE`.

`PRICE_CHANGED` `details`: `{ "items": [ { "product_id": uuid, "price_vnd": int } ], "delivery_fee_vnd": int, "total_vnd": int }`. `MIN_QTY` `details`: `{ "min_qty": int }`. `DATE_LEAD` `details`: `{ "lead_days": int }`. `DATE_HORIZON` `details`: `{ "max_days_ahead": int }`. `DATE_CAPACITY` `details`: `{ "delivery_date": date }`. `PRODUCT_UNAVAILABLE` `details`: `{ "product_ids": [uuid] }`, all products of the request that are unknown or inactive, in request order [v1.8 | 2026-10-26]. The check runs before capacity, so no `customer_order`, item, `day_load` or `order_event` row is written and no idempotency record is kept; the same key may be sent again with changed content (hidden cake in a draft, ADR-0011; AC-34).

Side effects: one row in `customer_order`, one per item in `customer_order_item`, an increase of `day_load.cakes_accepted`, one `order_event` of type `created` (all in one transaction, opened inside `OrderRepository.insertOrder` [v1.12 | 2026-10-29]). No notification in this slice.

Idempotency: see ADR-0008. Same key and same normalised body returns the stored result (200). Same key and different body returns 422 `IDEMPOTENCY_KEY_REUSED`. Two simultaneous requests with the same key create one order. A key whose earlier attempt was rejected (no order exists) is processed again normally. The client keeps one key until the order content changes [v1.11 | 2026-10-28]: it replaces the key on every change of any body field (including `expected_total_vnd`) and keeps it for a pure retry; the replay is evaluated before date, price and capacity rules and the hash includes `expected_total_vnd` (ADR-0008 v1.1, clarification only).

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
