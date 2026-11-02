# Data Model: Changes to orders, events, cakes and settings for admin-orders

Part of [data-model.md](../data-model.md) (index, version, change log), sections 11 to 16. New in v1.6 [v1.6 | 2026-10-31]. Aligned with PRD v1.6 in v1.9: four cancel reasons, one window rule, ids renumbered [v1.9 | 2026-10-31]. Migrations `backend/db/migrations/0003_admin_orders.sql` and `0004_admin_settings.sql` and `0005_admin_cakes.sql` (after `0002_admin_auth.sql`; `0003` built in B2 and B3, section 11 only; `0004` is section 13; `0005` is section 12 and the D-2 fix, built in B6 [v1.20 | 2026-11-01]). Decisions: ADR-0025, ADR-0028 to ADR-0032.

## 11. customer_order and order_event (FR-14, FR-18, FR-27; BR-3, BR-8, BR-9; TQ-8) [v1.9 | 2026-10-31]

New columns on `customer_order`:

| Column | Type | Null | Default | Constraints | Notes |
| ------ | ---- | ---- | ------- | ----------- | ----- |
| cancel_reason | text | yes | null | CHECK in `customer_asked`, `cannot_deliver`, `cannot_reach_customer`, `fake_spam` (`day_full` removed [v1.9 | 2026-10-31]); CHECK `(status = 'Cancelled') = (cancel_reason IS NOT NULL)` | Working copy; the event is the record |
| is_demo | boolean | no | false | | Only for review-account demo rows (ADR-0027); excluded from `day_load`, from the per-phone count and from every normal query; a review account sees only these rows |

New columns on `order_event`: `reason` text null (CHECK same value list; set only when `to_status = 'Cancelled'`), `actor_name` text null (name snapshot of the account; null for customer and system). New FK `order_event.actor_id` to `account(id)` (nullable). Event types stay `created` and `status_changed`.

Triggers (replaced with `CREATE OR REPLACE`, same names):

| Trigger | Change |
| ------- | ------ |
| `customer_order_release_capacity` | The inserted event also takes `reason = NEW.cancel_reason` and `actor_name = NULLIF(current_setting('app.actor_name', true), '')`. Capacity release on `Cancelled` is the rule of 0001, with no `GREATEST` floor (see "Cancelling and `day_load`" below) [v1.10 | 2026-11-01] |
| `customer_order_immutable` | `cancel_reason` and `is_demo` are not snapshot columns, but a set `cancel_reason` cannot change or clear (raises `check_violation`) |
| `customer_order_status_guard` | Unchanged (the four transitions of order-lifecycle.md section 6) |

Migration guard: a `DO` block raises an error if any `Cancelled` row exists before the CHECK is added.

Per-phone rule (ADR-0030): a stored order counts toward the limit when `status <> 'Cancelled' OR cancel_reason = 'fake_spam'`, within 24 hours of `created_at` (built in `PostgresOrderRepository.countOrders`; `POST /v1/orders` in api/03 step 7 states the same) [v1.10 | 2026-11-01].

Cancelling and `day_load` [v1.10 | 2026-11-01]: when an order becomes `Cancelled` the trigger runs `UPDATE day_load SET cakes_accepted = cakes_accepted - OLD.total_cakes` for the order's `(shop_id, delivery_date)`. Migration 0003 has no `GREATEST(..., 0)` floor (an earlier design had one; it was removed) and one must not return, because it would hide a wrong counter. The guards are: the CHECK `cakes_accepted >= 0` (a cancel that would go below zero fails and rolls back, only possible if the counter was edited by hand); the compare-and-set of ADR-0028 (a repeated cancel changes nothing, so cakes return once); and a missing row (a past date whose row was removed) is simply not touched, the cancel succeeds. `capacity_limit` is not changed by a cancel. A cancelled order only frees room: the date shows more remaining at once. Completing and confirming do not touch `day_load`. A cancel that would go below zero [v1.14 | 2026-11-01]: the CHECK `day_load_within_limit` fails, the transaction rolls back (order, event and counter unchanged) and `AdminOrderStore` answers 500 `INTERNAL_ERROR` with `details.reason = DAY_LOAD_INCONSISTENT` and a log line without data; nothing is repaired automatically and there is no `GREATEST` floor (ADR-0030). The operator fixes the counter by hand. Defect D-2 is fixed in `0005_admin_cakes.sql`: `customer_order_release_capacity` is replaced and skips the `day_load` update when `OLD.is_demo` (demo rows are excluded from `day_load`) [v1.20 | 2026-11-01].

Indexes added: `customer_order (shop_id, created_at)` (finished orders of the 90-day window, ADR-0029). The existing `(shop_id, delivery_date, status)`, `(shop_id, status, created_at)` and `(customer_phone, created_at)` serve the list and the per-phone check. Extension `unaccent` (ADR-0029). Partial index `customer_order (shop_id, delivery_date) WHERE status IN ('New','Confirmed')` serves the open-orders part of the window predicate and the badge count (ADR-0029 v1.3); it holds only open orders, so it stays tiny. There is no Unfinished view, no `new_count` query and no `status = 'Cancelled'`-only index [v1.9 | 2026-10-31].

## 12. product, product_image (FR-21; BR-11, BR-12; ADR-0025, ADR-0031) [v1.9 | 2026-10-31]

Changes to `product`:

| Column | Change |
| ------ | ------ |
| image_path | Becomes nullable (uploaded cakes have no file) |
| image_source | New `text NOT NULL DEFAULT 'file'`, CHECK `file` or `upload`; CHECK `image_source = 'upload' OR image_path IS NOT NULL` |
| removed_at | New `timestamptz NULL`; CHECK `removed_at IS NULL OR is_active = false` |
| price_vnd | Added CHECK `<= 100000000` (the lower bound 1 is checked by the service: Place Order tests use 0 rows) |

Constraints: partial UNIQUE `(shop_id, lower(name)) WHERE removed_at IS NULL`; trigger `product_cap_guard` (`BEFORE INSERT OR UPDATE OF removed_at`; takes `FOR UPDATE` on the `shop_setting` row, then counts the other non-removed rows) refuses a 13th non-removed cake on insert and when an update brings a removed cake back (`removed_at` from set to null); other updates return at once. The service checks first and answers `CAKE_LIMIT_REACHED`; the trigger is the last line of defence [v1.20 | 2026-11-01]. "At least one active cake" is enforced by the service under the same row lock because Place Order treats zero active products as a legal error state (ADR-0031). The admin list and the customer catalog filter `removed_at IS NULL` (catalog also filters `is_active`); built in B6. The sample cakes keep `image_source = 'file'` and their `image_path`; uploaded cakes have `image_source = 'upload'` and no path [v1.20 | 2026-11-01].

New table `product_image`:

| Column | Type | Null | Constraints | Notes |
| ------ | ---- | ---- | ----------- | ----- |
| product_id | uuid | no | PK, FK product | One image per cake |
| content_type | text | no | CHECK `image/jpeg` or `image/png` | From the file signature |
| bytes | bytea | no | CHECK `octet_length(bytes) BETWEEN 1 AND 5242880` | |
| width, height | integer | no | CHECK between 200 and 4096 | From the header |
| sha256 | text | no | length 64 | First 8 characters make the `?v=` value |
| created_at | timestamptz | no | default now() | |

Removal deletes the `product_image` row and sets `removed_at` and `is_active = false` in one transaction; the row of a removed cake is never read (the image route joins `removed_at IS NULL`) [v1.20 | 2026-11-01]. Image absence for an active uploaded cake is prevented by one transaction (product plus image); no cross-table CHECK exists.

## 13. shop_setting, district, delivery_slot (FR-22 to FR-24; BR-11) [v1.9 | 2026-10-31]

New CHECKs on `shop_setting`: `daily_limit <= 9999`, `lead_days <= 14`, `min_qty <= 20`, `min_qty <= daily_limit`. On `district`: `delivery_fee_vnd <= 10000000` (lower bound 1 by the service). Built in `0004_admin_settings.sql` (B5) [v1.11 | 2026-11-01]. The service also checks the lower bounds and answers 422 before the CHECK can fire. A district name is unique ignoring letter case (checked in the service under the `shop_setting` row lock; field `name`, code `NAME_TAKEN`). Slot `sort_order` is renumbered by clock time (start, then end) after every add or move; a new district gets `max(sort_order) + 1`. Existing unique indexes already stop duplicate district names and slots; `end_time > start_time` exists. Existing `max_days_ahead >= lead_days` stays (30 against 14). Every change writes `settings_change` rows (section 3.16) in the same transaction.

### day_load and the daily limit [v1.6 | 2026-10-31]

`day_load.capacity_limit` is only a copy of the limit written by the last accepted order for that date, kept so the CHECK `cakes_accepted <= capacity_limit` can exist. It is not an authority. Availability and order placement read `shop_setting.daily_limit` (existing behaviour, section 3.6). Consequences when the owner changes the limit:

- Lowering: no `day_load` row is touched. A date with `cakes_accepted` above the new limit keeps its old, larger `capacity_limit`, so the CHECK still holds; remaining = `daily_limit - cakes_accepted` is zero or negative, the date shows as full, new orders there are refused, and cancellations lower `cakes_accepted` as before (BR-11).
- Raising: nothing to do; the next accepted order's conditional upsert sets `capacity_limit` to the new limit (the update only runs when `cakes_accepted + n <= daily_limit`, so the CHECK holds).
- Preview (FR-22): dates from the server date onward with `cakes_accepted > :new_limit`, read from `day_load` only.

## 14. Retention and purge jobs

SECURITY EVENT PURGE BLOCKED UNTIL `0007` [v1.22 | 2026-11-02]: verified on PostgreSQL 16.15, trigger `security_event_append_only()` (`0002`) refuses every DELETE, so the 180-day delete of `security_event` fails today. Migration `0007_security_event_purge.sql` is being built (ADR-0032); only after it is applied does that purge work. The go-live gate below stays open until the database tests pass. The purge also copies each deleted row to `security_event_archive` (section 15) [v1.23 | 2026-11-02].

BUILT [v1.21 | 2026-11-02]: `backend/Sources/App/Services/Admin/Auth/Maintenance/` (`MaintenancePolicy`, `MaintenancePurge`, `MaintenanceScheduler`). The database tests (`MaintenancePurgeTests`) have NOT yet run against PostgreSQL (no database on the dev host) and the session and security-event deletes have no test, so the go-live gate (`auth_code` rows keep addresses; needed before real staff use) stays open until they pass in CI or locally. Not started under `APP_ENV=testing`. Periods as built: `auth_code` 24 h after `expires_at`; `device_session` 30 days after `revoked_at` or `refresh_expires_at`; `security_event` 180 days after `at`; one DELETE per table. Possible later: an index on `auth_code (expires_at)` (the existing index is on `created_at`). Design: a maintenance task inside the backend (once at start-up and then every 24 h; idempotent, safe to run twice) deletes: `auth_code` rows 24 h after expiry; revoked or expired `device_session` rows 30 days later; `security_event` rows older than 180 days. Orders are not purged (retention pending, DM-Q1); the 90-day display window is not retention (ADR-0029).

## 15. Migrations

| File | Content |
| ---- | ------- |
| `0002_admin_auth.sql` | Tables `account`, `device_session`, `auth_code`, `security_event` (sections 3.10 to 3.15), triggers, indexes. It does NOT hold `settings_change`; earlier text said it did [v1.11 | 2026-11-01] |
| `0003_admin_orders.sql` (built, B2 and B3) | Section 11 changes: `cancel_reason`, `is_demo`, `order_event.reason` and `actor_name`, the actor foreign key, two indexes, `search_fold()` on `unaccent` when the host allows it, replaced trigger functions; stops with an error if a `Cancelled` row exists. Section 12 (cakes) is not in it; the settings part is `0004` [v1.11 | 2026-11-01] |
| `0005_admin_cakes.sql` (built, B6) [v1.20 | 2026-11-01] | Section 12: `product.image_path` nullable, `image_source`, `removed_at`, CHECKs `product_image_source_valid`, `product_image_path_for_file`, `product_removed_is_inactive`, `product_price_max`; unique index `product_shop_name_live`; table `product_image`; function and trigger `product_cap_guard`; replaced `customer_order_release_capacity` (D-2). Forward-only; the previous release reads the same columns |
| `0006_review_account.sql` (built, review account) [v1.14 | 2026-11-01] | Replaces `order_event_append_only()`: an `UPDATE` is still refused, a `DELETE` is allowed only when the event's order has `is_demo = true`. Needed by `review-account off`, which deletes demo orders with their history. Real orders keep an append-only history. Forward-only; the previous release never deletes events |
| `0004_admin_settings.sql` (built, B4 and B5) | Table `settings_change` (section 3.16: append-only trigger, index `(shop_id, changed_at)`); CHECKs `shop_setting_daily_limit_max` (<= 9999), `_lead_days_max` (<= 14), `_min_qty_max` (<= 20), `_min_qty_within_limit` (`min_qty <= daily_limit`); `district_delivery_fee_max` (<= 10000000). Forward-only; the cake changes (section 12) are in `0005` [v1.12 | 2026-11-01] |
| `0007_security_event_purge.sql` (being built, ADR-0032) [v1.22 | 2026-11-02] | Replaces `security_event_append_only()`: an `UPDATE` is still refused; a `DELETE` is allowed only for rows with `at` older than 180 days; any other DELETE raises the same append-only error. Also creates `security_event_archive` (same columns plus `archived_at`) with its own append-only trigger; the purge moves rows with one `WITH moved AS (DELETE ... RETURNING *) INSERT` statement [v1.23 | 2026-11-02]. Needed by the purge task. The 180 days live in SQL and in `MaintenancePolicy.securityEventAge`; a test keeps them equal. Forward-only; the previous release never deletes events |

### 15.1 Database change policy [v1.23 | 2026-11-02]

Owner decision 2026-11-02; ADR-0032.

1. Every schema or trigger change is a new numbered file in `backend/db/migrations/` (next free number, forward-only).
2. An applied migration is never edited; a fix is a new migration.
3. The documents name the migration version that holds each change.
4. Before applying migrations to a database, take a `pg_dump` of that database. Save: a full dump in custom format (`pg_dump --format=custom`), connected with `DATABASE_MIGRATION_URL`. Keep it where the operator controls access (encrypted, as in deployment/03 section 6); never in the repository or in CI artifacts of this public repository. Name it with the database, date and the last applied migration number.
5. Restore: create an empty database and run `pg_restore --no-owner --dbname <empty database>` with the dump file; then run the reconciliation query of deployment/03 section 6. A dump counts only after one such test restore.
6. The deploy job does not apply migrations until the dump of step 4 exists for that run (operator step in the runbook; automation is a later change).

Both are forward-only and additive: the previous backend release still runs against them (the new columns have defaults or are nullable; the replaced triggers write the same event shape plus nulls). The first owner row comes from the `create-owner` command [v1.14 | 2026-11-01], not from a migration. Sample seed gets no accounts.

## 16. Traceability [v1.9 | 2026-10-31]

| Entity or change | FR / BR (PRD v1.6) |
| ---------------- | ------------------ |
| account | FR-1, FR-3, FR-5, BR-1, BR-4, BR-6 |
| device_session | FR-2, FR-4, FR-5, FR-6, FR-7, BR-5, BR-13 |
| auth_code (with `wrong_count`) | FR-1, FR-6, BR-4 |
| device_session.push_token | FR-25, FR-26 |
| security_event | FR-4, FR-6, FR-7 (audit of access, G-4) |
| settings_change | FR-20 to FR-24, BR-3 |
| cancel_reason, order_event.reason, actor_name | FR-14, FR-18, FR-27, BR-3, BR-8 |
| product removal, product_image | FR-21, BR-11, BR-12 |
| shop_setting CHECKs | FR-22, FR-24, BR-11 |
| window index, open-orders partial index | FR-9, FR-13, BR-9 |
