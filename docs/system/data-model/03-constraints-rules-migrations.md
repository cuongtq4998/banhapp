# Data Model: Indexes, data rules, sensitive data, migrations, traceability

Part of [data-model.md](../data-model.md) (index, version, change log), sections 5 to 9. Moved from data-model.md v1.3 with the wording unchanged unless a line carries a newer label [v1.4 | 2026-10-27].

## 5. Indexes & Constraints

| Object | Definition | Reason |
| ------ | ---------- | ------ |
| PK `day_load (shop_id, delivery_date)` | | One counter per date; row lock serialises competing orders (AC-22) |
| CHECK on `day_load` | `cakes_accepted >= 0 AND cakes_accepted <= capacity_limit` | Limit can never be exceeded even by faulty code (BR-1) |
| UNIQUE `customer_order (order_code)` | | Unique code (AC-16) |
| UNIQUE `customer_order (shop_id, idempotency_key)` | | One order per confirmation attempt (FR-16, AC-19) |
| INDEX `customer_order (shop_id, delivery_date, status)` | | Later: shop lists the orders of a day; reconciliation with `day_load` |
| INDEX `customer_order (customer_phone, created_at)` | | Per-phone rate limit lookup (ADR-0014) |
| INDEX `customer_order (shop_id, status, created_at)` | | Later: new-order list for staff |
| UNIQUE `product (shop_id, slug)`, `district (shop_id, name)`, `delivery_slot (shop_id, start_time, end_time)` | | No duplicates in configuration |
| FKs | `customer_order.slot_id`, `district_id`, `customer_order_item.product_id`, all `shop_id` | Integrity; `ON DELETE RESTRICT`: configuration rows used by an order cannot be deleted (use `is_active = false`) |
| Trigger `customer_order_status_guard` (BEFORE UPDATE OF status) | Allows only the transitions in order-lifecycle.md section 6; rejects any other change including changes of a final state; sets `status_changed_at` | The server rejects invalid transitions even for direct SQL |
| Trigger `customer_order_release_capacity` (AFTER UPDATE OF status) | On every status change inserts an `order_event` (`status_changed`, from, to, actor from `app.actor_type` / `app.actor_id`, default `system`); when the new status is `Cancelled` it also runs `UPDATE day_load SET cakes_accepted = cakes_accepted - OLD.total_cakes` for the order's date. An update that leaves the status unchanged does nothing [v1.2 \| 2026-10-26] | BR-9, AC-28, audit (order-lifecycle.md section 8) |
| Trigger `customer_order_immutable` (BEFORE UPDATE) | Rejects changes to any column except `status`, `payment_status`, `status_changed_at`, `updated_at`, `pii_purged_at` and the personal columns when `pii_purged_at` is being set | Snapshots must not change (BR-6) |
| Trigger on `order_event` | Rejects UPDATE and DELETE | Append-only audit |

Migration review 2026-10-26: `backend/db/migrations/0001_init.sql` matches sections 3 to 5 column by column, constraint by constraint and index by index; the only gap was the wording of the trigger row above, so the document changed and the migration did not. Trigger firing order on `customer_order` is alphabetical (`customer_order_immutable`, `customer_order_status_guard` before the update; `customer_order_release_capacity` after). [v1.2 | 2026-10-26]

Rules enforced only in application code (they depend on configuration): lead time (BR-2), horizon (BR-8), minimum quantity (BR-4), served district (BR-3, also the foreign key and `is_active`), per-cake maximum, price acknowledgement (ADR-0010).

## 6. Data Rules

- Money: whole VND integers; no decimals, no rounding (BR-5). Totals are computed only by the server; all arithmetic is also checked by CHECK constraints.
- Time: instants in UTC (`timestamptz`); the order date (A-8) and all rule dates are computed in `shop.timezone`. A delivery date is a calendar date without time zone.
- Identifiers: UUID primary keys; the customer sees only `order_code`. Order codes are not sequential (ADR-0009).
- Deletion: no hard delete of orders in this slice. Configuration rows are deactivated, not deleted. Cancellation is a status change, not a delete.
- Retention (BR-12): the period is not decided by the owner. Until then personal data is kept; the design supports erasing name, phone, address and note by setting `pii_purged_at` (a purge job and a period will be added when the owner states it).
- Normalisation: text is trimmed and Unicode NFC normalised before storage; phone stored in E.164 (ADR-0009).
- Sample data: rows with `is_sample = true` are seed data; the apps do not see the flag (AC-29). Seed text that can reach a screen carries no sample marker ("mẫu", "sample", "test", "demo", "fake"). Seed `phone_contact` is a fake number that passes the ADR-0009 pattern: `+84` then `[35789]` then 8 digits, in the fake range `+84900000000` to `+84900000099`; `zalo_contact` is the same number without `+`. No official reserved fictional range exists that I found (unverified), so these are numbers unlikely to be assigned; they never go into a store listing. [v1.3 | 2026-10-26]
- `settings.note_max_length` in the API is a code constant (200, input-safety bound of ADR-0009) equal to the `customer_order.note` check; `shop_setting` has no column for it [v1.3 | 2026-10-26].

## 7. Sensitive Data

| Field | Classification | Who may read | Retention |
| ----- | -------------- | ------------ | --------- |
| customer_order.customer_name | personal | Backend service role; later: shop staff and owner | Until the retention period (BR-12, open); purge sets `pii_purged_at` |
| customer_order.customer_phone | personal | Same | Same |
| customer_order.customer_address | personal | Same | Same |
| customer_order.note | personal (may contain any text) | Same | Same |
| customer_order.idempotency_key, request_hash | operational (the hash covers personal fields; it is a one-way digest) | Backend | With the order |
| customer_order.client_platform, app_version | operational | Backend | With the order |
| order_event | operational | Backend; later staff | With the order |
| Device draft (not in the database; ADR-0011) | personal | Only the customer's device (app-private storage, excluded from backups) | Until the order is confirmed or 24 hours after the last change |
| Server logs | operational; must never contain name, phone, address, note | Operators | 30 days (deployment.md) |

Backups contain personal data: they are encrypted (deployment.md section 6). Real customer data never enters the repository, fixtures or test environments; fixtures use fake data.

## 8. Migrations

- SQL files in `backend/db/migrations`, named `NNNN_<slug>.sql`, applied in order by a Vapor `migrate` command that wraps each file in a Fluent migration (`SQLDatabase.raw`); Fluent records applied versions in its `_fluent_migrations` table (replaces the former `schema_migration` table) [v1.1 | 2026-10-25]. Production migrations run from CI with the migration role before the new image is deployed.
- Each file is forward-only and written so the previous release of the backend still works (expand, then contract in a later release). A down script is provided where simple (adding a column) and not provided where data would be lost.
- Initial migration `0001_init.sql` creates all tables, constraints, indexes and triggers above. Seed `backend/db/seed/sample.sql` is separate and runs only in local and staging (and in production once, for sample launch data, by the operator).
- Impact on existing data: none (new database).

## 9. Traceability

| Entity | FR / BR |
| ------ | ------- |
| shop | FR-2, FR-14 |
| shop_setting | BR-1, BR-2, BR-4, BR-8, BR-10 |
| product | FR-3, FR-4, FR-5, BR-5, BR-6 |
| district | FR-8, BR-3 |
| delivery_slot | FR-7, BR-11 |
| day_load | BR-1, BR-9 |
| customer_order, customer_order_item | FR-8, FR-9, FR-11, FR-16, FR-18, BR-5, BR-6, BR-7, BR-12 |
| order_event | order-lifecycle.md; supports later staff features |
