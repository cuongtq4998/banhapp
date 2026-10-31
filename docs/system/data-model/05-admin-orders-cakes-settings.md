# Data Model: Changes to orders, events, cakes and settings for admin-orders

Part of [data-model.md](../data-model.md) (index, version, change log), sections 11 to 16. New in v1.6 [v1.6 | 2026-10-31]. Migration `backend/db/migrations/0003_admin_orders_catalog.sql` (after `0002_admin_auth.sql`). Decisions: ADR-0025, ADR-0028 to ADR-0031.

## 11. customer_order and order_event (FR-14, FR-18, FR-20, FR-44; BR-4, BR-16; TQ-8)

New columns on `customer_order`:

| Column | Type | Null | Default | Constraints | Notes |
| ------ | ---- | ---- | ------- | ----------- | ----- |
| cancel_reason | text | yes | null | CHECK in `customer_asked`, `day_full`, `cannot_deliver`, `cannot_reach_customer`, `fake_spam`; CHECK `(status = 'Cancelled') = (cancel_reason IS NOT NULL)` | Working copy; the event is the record |
| is_demo | boolean | no | false | | Only for review-account demo rows (ADR-0027); excluded from `day_load` and from every normal query |

New columns on `order_event`: `reason` text null (CHECK same value list; set only when `to_status = 'Cancelled'`), `actor_name` text null (name snapshot of the account; null for customer and system). New FK `order_event.actor_id` to `account(id)` (nullable). Event types stay `created` and `status_changed`.

Triggers (replaced with `CREATE OR REPLACE`, same names):

| Trigger | Change |
| ------- | ------ |
| `customer_order_release_capacity` | The inserted event also takes `reason = NEW.cancel_reason` and `actor_name = NULLIF(current_setting('app.actor_name', true), '')`. Capacity release on `Cancelled` unchanged |
| `customer_order_immutable` | `cancel_reason` and `is_demo` are not snapshot columns, but a set `cancel_reason` cannot change or clear (raises `check_violation`) |
| `customer_order_status_guard` | Unchanged (the four transitions of order-lifecycle.md section 6) |

Migration guard: a `DO` block raises an error if any `Cancelled` row exists before the CHECK is added.

Per-phone rule (ADR-0030): a stored order counts toward the limit when `status <> 'Cancelled' OR cancel_reason = 'fake_spam'`.

Indexes added: `customer_order (shop_id, created_at)` (90-day window scan, ADR-0029). The existing `(shop_id, delivery_date, status)`, `(shop_id, status, created_at)` and `(customer_phone, created_at)` serve the list, the New count and the per-phone check. Extension `unaccent` (ADR-0029). Partial index `customer_order (shop_id, delivery_date) WHERE status IN ('New','Confirmed')` serves the Unfinished view and its count (ADR-0029 v1.2, TQ-12); it holds only open orders, so it stays tiny [v1.8 | 2026-10-31].

## 12. product, product_image (FR-22, FR-38, FR-39; BR-11, BR-18, BR-19; ADR-0025, ADR-0031)

Changes to `product`:

| Column | Change |
| ------ | ------ |
| image_path | Becomes nullable (uploaded cakes have no file) |
| image_source | New `text NOT NULL DEFAULT 'file'`, CHECK `file` or `upload`; CHECK `image_source = 'upload' OR image_path IS NOT NULL` |
| removed_at | New `timestamptz NULL`; CHECK `removed_at IS NULL OR is_active = false` |
| price_vnd | Added CHECK `<= 100000000` (the lower bound 1 is checked by the service: Place Order tests use 0 rows) |

Constraints: partial UNIQUE `(shop_id, lower(name)) WHERE removed_at IS NULL`; trigger `product_cap_guard` (takes `FOR UPDATE` on the `shop_setting` row, then counts non-removed rows) refuses a 13th non-removed cake. "At least one active cake" is enforced by the service under the same row lock because Place Order treats zero active products as a legal error state (ADR-0031). The admin list and the customer catalog filter `removed_at IS NULL` (catalog already filters `is_active`).

New table `product_image`:

| Column | Type | Null | Constraints | Notes |
| ------ | ---- | ---- | ----------- | ----- |
| product_id | uuid | no | PK, FK product | One image per cake |
| content_type | text | no | CHECK `image/jpeg` or `image/png` | From the file signature |
| bytes | bytea | no | CHECK `octet_length(bytes) BETWEEN 1 AND 5242880` | |
| width, height | integer | no | CHECK between 200 and 4096 | From the header |
| sha256 | text | no | length 64 | First 8 characters make the `?v=` value |
| created_at | timestamptz | no | default now() | |

Removal deletes the `product_image` row. Image absence for an active uploaded cake is prevented by one transaction (product plus image); no cross-table CHECK exists.

## 13. shop_setting, district, delivery_slot (FR-23 to FR-26, FR-28, FR-40; BR-9, BR-21)

New CHECKs on `shop_setting`: `daily_limit <= 9999`, `lead_days <= 14`, `min_qty <= 20`, `min_qty <= daily_limit`. On `district`: `delivery_fee_vnd <= 10000000` (lower bound 1 by the service). Existing unique indexes already stop duplicate district names and slots; `end_time > start_time` exists. Existing `max_days_ahead >= lead_days` stays (30 against 14). Every change writes `settings_change` rows (section 3.16) in the same transaction.

### day_load and the daily limit [v1.6 | 2026-10-31]

`day_load.capacity_limit` is only a copy of the limit written by the last accepted order for that date, kept so the CHECK `cakes_accepted <= capacity_limit` can exist. It is not an authority. Availability and order placement read `shop_setting.daily_limit` (existing behaviour, section 3.6). Consequences when the owner changes the limit:

- Lowering: no `day_load` row is touched. A date with `cakes_accepted` above the new limit keeps its old, larger `capacity_limit`, so the CHECK still holds; remaining = `daily_limit - cakes_accepted` is zero or negative, the date shows as full, new orders there are refused, and cancellations lower `cakes_accepted` as before (BR-10).
- Raising: nothing to do; the next accepted order's conditional upsert sets `capacity_limit` to the new limit (the update only runs when `cakes_accepted + n <= daily_limit`, so the CHECK holds).
- Preview (BR-10): dates from the server date onward with `cakes_accepted > :new_limit`, read from `day_load` only.

## 14. Retention and purge jobs

A maintenance task inside the backend (once at start-up and then every 24 h; idempotent, safe to run twice) deletes: `auth_code` rows 24 h after expiry; revoked or expired `device_session` rows 30 days later; `security_event` rows older than 180 days. Orders are not purged (retention pending, DM-Q1); the 90-day display window is not retention (ADR-0029).

## 15. Migrations

| File | Content |
| ---- | ------- |
| `0002_admin_auth.sql` | Tables `account`, `device_session`, `auth_code`, `security_event`, `settings_change` (sections 3.10 to 3.16), triggers, indexes |
| `0003_admin_orders_catalog.sql` | Section 11 to 13 changes, extension `unaccent`, replaced trigger functions |

Both are forward-only and additive: the previous backend release still runs against them (the new columns have defaults or are nullable; the replaced triggers write the same event shape plus nulls). The first owner row comes from the `bootstrap-owner` command, not from a migration. Sample seed gets no accounts.

## 16. Traceability

| Entity or change | FR / BR |
| ---------------- | ------- |
| account | FR-1, FR-5, FR-27, FR-42, BR-1, BR-7, BR-8 |
| device_session | FR-4, FR-7, FR-36, FR-37, BR-6, BR-8 |
| auth_code (with `wrong_count`) | FR-1 to FR-3, FR-6, FR-43, BR-5, BR-17 |
| device_session.push_token | FR-31, FR-33 to FR-35 |
| security_event | FR-37, G-4 (audit of access) |
| settings_change | FR-30 |
| cancel_reason, order_event.reason, actor_name | FR-18, FR-20, FR-44, BR-4, BR-16 |
| product removal, product_image | FR-22, FR-38, FR-39, BR-11, BR-18, BR-19 |
| shop_setting CHECKs | FR-24, FR-28, FR-40, BR-9, BR-21 |
| window index, open-orders partial index | FR-41, FR-48, FR-49, BR-20, BR-27 |
