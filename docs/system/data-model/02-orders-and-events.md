# Data Model: Order entities, events, enumerations

Part of [data-model.md](../data-model.md) (index, version, change log), sections 3.7 to 3.9, 4. Moved from data-model.md v1.3 with the wording unchanged unless a line carries a newer label [v1.4 | 2026-10-27].

## 3. Entities (continued)

### 3.7 customer_order (FR-8, FR-11, FR-16, FR-18, BR-5 to BR-7, BR-12)

Purpose: one order. Prices and names that affect the order are snapshotted (standard 04 rule 3).

| Column | Type | Null | Default | Constraints | Notes |
| ------ | ---- | ---- | ------- | ----------- | ----- |
| id | uuid | no | generated | PK | Internal only; never shown to the customer |
| shop_id | uuid | no | | FK shop | |
| order_code | text | no | | unique; `^BT-[2-9A-HJKMNP-Z]{6}$` | Customer-facing code (ADR-0009, AC-16) |
| status | text | no | `New` | CHECK in `New`, `Confirmed`, `Completed`, `Cancelled` | Section 5; transitions guarded by trigger |
| payment_status | text | no | `unpaid` | CHECK in `unpaid`, `paid` | Placeholder for the later payment feature. Not exposed by any API in this slice (FR-19) |
| delivery_date | date | no | | | Shop-local date. Lead and horizon rules are checked at write time against the order date; not a table constraint because they depend on configuration (BR-2, BR-8) |
| slot_id | uuid | no | | FK delivery_slot | |
| slot_start_time, slot_end_time | time | no | | | Snapshot of the slot |
| district_id | uuid | no | | FK district | |
| district_name | text | no | | | Snapshot |
| delivery_fee_vnd | integer | no | | `>= 0` | Snapshot of the district fee (BR-3) |
| items_subtotal_vnd | integer | no | | `>= 0` | Sum of line totals |
| total_vnd | integer | no | | `>= 0`; CHECK `total_vnd = items_subtotal_vnd + delivery_fee_vnd` | BR-5 |
| total_cakes | integer | no | | `>= 1` | Sum of item quantities; the value added to `day_load` |
| customer_name | text | no | | length 1 to 100 (or purged) | Personal data (BR-7) |
| customer_phone | text | no | | E.164 `^\+84[35789][0-9]{8}$` (or purged) | Personal data; stored normalised (ADR-0009) |
| customer_address | text | no | | length 1 to 250 (or purged) | Personal data; district stored separately |
| note | text | yes | null | length 0 to 200 | Personal data possible (FR-18) |
| idempotency_key | uuid | no | | unique with `shop_id` | FR-16 (ADR-0008) |
| request_hash | text | no | | length 64 | SHA-256 hex of the normalised request body |
| client_platform | text | no | | CHECK in `ios`, `android` | Operational |
| app_version | text | no | | length 1 to 20 | Operational |
| status_changed_at | timestamptz | no | now() | | |
| pii_purged_at | timestamptz | yes | null | | Set when name, phone, address, note were erased (BR-12); the purge job is outside this slice |
| created_at, updated_at | timestamptz | no | now() | | `created_at` is the order date in UTC; the order date in shop time is derived with `shop.timezone` (A-8) |

Rule: the length and pattern checks on the three personal columns are written as `(pii_purged_at IS NOT NULL OR <check>)`, so a purge can blank them.

### 3.8 customer_order_item (FR-5, BR-5, BR-6, AC-6)

Purpose: one product line of an order, with the price at confirmation.

| Column | Type | Null | Default | Constraints | Notes |
| ------ | ---- | ---- | ------- | ----------- | ----- |
| order_id | uuid | no | | PK part, FK customer_order (ON DELETE RESTRICT) | |
| product_id | uuid | no | | PK part, FK product | One line per product |
| product_name | text | no | | | Snapshot |
| unit_price_vnd | integer | no | | `>= 0` | Price at confirmation (BR-6, AC-23) |
| quantity | integer | no | | between 1 and 99 | Zero-quantity lines are not stored (AC-6) |
| line_total_vnd | integer | no | | CHECK `line_total_vnd = unit_price_vnd * quantity` | |

### 3.9 order_event (order-lifecycle.md section 9)

Purpose: append-only audit trail of an order's life.

| Column | Type | Null | Default | Constraints | Notes |
| ------ | ---- | ---- | ------- | ----------- | ----- |
| id | bigint | no | identity | PK | |
| order_id | uuid | no | | FK customer_order | |
| event_type | text | no | | CHECK in `created`, `status_changed` | More types may be added by later features [v1.6 | 2026-10-31] |
| from_status | text | yes | null | | Null for `created` |
| to_status | text | no | | | |
| actor_type | text | no | | CHECK in `customer`, `staff`, `owner`, `system` | `customer` for the `created` event (written by the application). Status-change events are written by trigger with `system` unless the transaction sets `app.actor_type` [v1.2 \| 2026-10-26] |
| actor_id | uuid | yes | null | | Null for `customer` and `system`; staff id by the admin status endpoint, taken from `app.actor_id` [v1.6 | 2026-10-31] [v1.2 \| 2026-10-26] |
| created_at | timestamptz | no | now() | | |

The table rejects UPDATE and DELETE by trigger (append-only).

Who writes it [v1.2 | 2026-10-26]: the `created` row is inserted by the order transaction (opened inside `OrderRepository.insertOrder`, [v1.5 | 2026-10-29]); the per-phone limit counts orders with `created_at` in the last 24 hours that are not cancelled, or are cancelled with reason `fake_spam` (served by the index `customer_order (customer_phone, created_at)`; ADR-0030, data-model/05) [v1.6 | 2026-10-31]. Every later row is inserted by the trigger `customer_order_release_capacity` on any status change (not only cancellation), so no code path can skip the audit. The trigger reads the actor from the transaction settings `app.actor_type` and `app.actor_id` (set with `set_config(name, value, true)` in the same transaction, before the status update); when absent or empty the actor is `system` with a null id. An `app.actor_type` outside the CHECK list fails the update. `customer_order.updated_at` is not maintained by a trigger: the application sets it in the same statement.

## 4. Enumerations

| Set | Value | Meaning |
| --- | ----- | ------- |
| customer_order.status | `New` | Received from the customer; the shop has not acted. Initial state |
| | `Confirmed` | The shop accepted the order (admin-orders) [v1.6 | 2026-10-31] |
| | `Completed` | Delivered (admin-orders) [v1.6 | 2026-10-31]. Final |
| | `Cancelled` | Cancelled by the shop (admin-orders) [v1.6 | 2026-10-31]. Final. Releases the date's capacity (BR-9) |
| customer_order.payment_status | `unpaid` | Initial and only value used now |
| | `paid` | Reserved for the payment feature |
| order_event.actor_type | `customer`, `staff`, `owner`, `system` | Who caused the event |
| customer_order.client_platform | `ios`, `android` | Source app |
