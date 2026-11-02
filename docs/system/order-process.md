# Order Process: statuses, transitions, queries

| Field | Value |
| ----- | ----- |
| Version | 1.0 [v1.0 | 2026-11-02] |
| Status | Draft |
| Owner | atlas-architect |
| Based on | product/admin-orders.md v1.10 (BR-2, BR-9, BR-11, BR-15, FR-13, FR-16 to FR-19, FR-28, FR-29); ADR-0033 |
| Related | order-lifecycle.md (creation flow; its section 6 is superseded by this file), data-model/06, api/09, ADR-0028, ADR-0029, ADR-0033 |

## 1. State machine [v1.0 | 2026-11-02]

```mermaid
stateDiagram-v2
    [*] --> Received: customer confirms
    Received --> Processing: staff starts
    Received --> Cancelled
    Processing --> DeliveryDateScheduled: expected date entered
    Processing --> Cancelled
    DeliveryDateScheduled --> DeliveryStarted: real fee entered
    DeliveryStarted --> Finished
    Finished --> [*]
    Cancelled --> [*]
```

Final: `Finished`, `Cancelled`. A date move is not a transition: status stays `DeliveryDateScheduled`.

## 2. Transition table

| From | To | Input (required) | Guard | Side effects |
| ---- | -- | ---------------- | ----- | ------------ |
| (none) | Received | customer order | rules of api.md 4.3 | capacity taken, event `created` |
| Received | Processing | none | owner or staff; `expected_status` | event |
| Processing | DeliveryDateScheduled | `expected_delivery_date` >= shop today | as above | sets the date; one `order_expected_date_change` row (old date null); event |
| DeliveryDateScheduled | DeliveryStarted | `delivery_fee_final_vnd` integer 0 to 10 000 000 | as above | stores fee and `delivery_fee_set_at`; event |
| DeliveryStarted | Finished | none | as above | event; capacity unchanged |
| Received, Processing | Cancelled | `cancel_reason` (ADR-0030) | as above | releases `total_cakes` on the requested date; event |
| (date move) | same status | `expected_delivery_date` >= shop today | status is `DeliveryDateScheduled` and stored date equals `previous_expected_delivery_date` | updates the date; one change row (old, new) |

Every other pair is refused: 422 `STATUS_TRANSITION_INVALID`, no write (includes cancel from `DeliveryDateScheduled` onward, skipping a step, leaving a final state). The database trigger `customer_order_status_guard` holds the same pairs (recreated in migration 0008).

## 3. Rules

- Compare-and-set and replay: ADR-0033 section Decision 2; check order of ADR-0028 unchanged (session, window with replay exception, fields, pair, then the conditional UPDATE).
- Capacity: only the requested `delivery_date` counts; moving the expected date changes no `day_load` row (BR-15).
- Fee: required only at DeliveryDateScheduled to DeliveryStarted; refused at every other step (`FIELD_NOT_ALLOWED`). Amount to collect = `items_subtotal_vnd + delivery_fee_final_vnd`, shown only after the fee exists; the stored estimate (`delivery_fee_vnd`) is shown to the customer only.
- The expected date is changeable only in `DeliveryDateScheduled`; unlimited times; no daily limit, lead-day or slot check.
- Customer is not messaged on a date move; no new push (ADR-0024 unchanged: push only for new orders).

## 4. Queries (shop date `:today`)

```sql
-- list date
COALESCE(expected_delivery_date, delivery_date) AS list_date
-- open set
status IN ('Received','Processing','DeliveryDateScheduled','DeliveryStarted')
-- badge and red mark
open AND COALESCE(expected_delivery_date, delivery_date) <= :today
-- window (ADR-0029, unchanged shape)
open OR (status IN ('Finished','Cancelled') AND created_at >= :today_start - 90 days)
-- sort
ORDER BY list_date, slot_start, created_at, id
```

Cursor note: the sort key now changes when a date moves, so a page can repeat or skip a row across pages; the apps refresh from page 1 after any status or date change (R-14 stays: list is the truth). Index: partial `customer_order_open_list_idx ON (shop_id, (COALESCE(expected_delivery_date, delivery_date)), slot_start_time, created_at, id) WHERE status IN (open four)` replaces the use of `customer_order_shop_date_status_idx` for the open view.

Filter values of `GET /v1/admin/orders?status=`: `todo` (the four open steps, default), each of the six names, `all` (api/09).

## 5. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-11-02 | First version (ADR-0033). |
