# Data Model: order process columns and migration 0008

Part of [data-model.md](../data-model.md). Version 1.5 [v1.5 | 2026-11-02]. Traces: BR-2, BR-9, BR-11, BR-15, BR-17, FR-28 to FR-30, AC-49 to AC-53; ADR-0033.

## 1. New columns on `customer_order` [v1.0 | 2026-11-02]

| Column | Type | Null | Rule | FR |
| ------ | ---- | ---- | ---- | -- |
| expected_delivery_date | date | yes | Mutable; set at Processing to DeliveryDateScheduled; CHECK: not null when status is DeliveryDateScheduled, DeliveryStarted (legacy Finished rows may be null) | FR-28 |
| delivery_fee_final_vnd | integer | yes | CHECK 0 to 10 000 000; CHECK null unless status in DeliveryStarted, Finished | FR-29 |
| delivery_fee_set_at | timestamptz | yes | Set with the fee | FR-29 |

`status` CHECK becomes the six values. `delivery_fee_vnd`, `total_vnd` and the total CHECK are unchanged (stored estimate, immutable, ADR-0033 Decision 4). The immutable trigger (`customer_order_immutable`) is replaced so the three new columns are mutable.

## 2. New table `order_expected_date_change`

| Column | Type | Rule |
| ------ | ---- | ---- |
| id | bigint identity | PK |
| order_id | uuid | FK `customer_order`, ON DELETE RESTRICT |
| old_date | date null | Null at first entry |
| new_date | date not null | |
| changed_by_account_id | uuid null | FK `account`; null if the account is later removed (name kept) |
| changed_by_name | text not null | Account name snapshot (`app.actor_name`) |
| changed_at | timestamptz | default now() |

Index `(order_id, id)`. Insert-only (a trigger refuses UPDATE and DELETE). Part of PII retention like `order_event` (BR-12 placeholder; name is staff data, not customer data).

## 3. Migration plan: 0008 and 0009 [v1.4 | 2026-11-02]

The plan is split into two files and two transactions: see data-model/07 (which step is in which file, order of application, failure state, checks). Steps 1 to 6 below (without the two tables) are `0008_order_process.sql`; the tables, functions, triggers and recreated trigger functions are `0009_order_process_records.sql`.

Forward-only; 0001 to 0007 are never edited (policy 15.1 in data-model/05).

Before applying (operator, rule 15.1 steps 4 to 6): take `pg_dump --format=custom` with `DATABASE_MIGRATION_URL`, name it with database, date and last migration `0007`, store it encrypted outside the repository, test-restore once. The deploy job does not apply 0008 without it. Rollback is a restore of that dump (no down script).

Steps, one transaction, in the order of the file [v1.3 | 2026-11-02]:

1. Count rows for the verify block; drop triggers `customer_order_status_guard` and `customer_order_release_capacity` (also stops `order_event` writes during the remap).
2. Drop the `status` CHECK and the index `customer_order_open_idx` (0003; its predicate names the old statuses `New`, `Confirmed`; replaced by the open-list index in step 6).
3. Add the three new columns (before the backfill, which writes one of them).
4. Remap `customer_order.status` only: New to Received, Confirmed to Processing, Completed to Finished, Cancelled unchanged. `order_event` is NOT touched [v1.1 | 2026-11-02]: no UPDATE, no trigger disabled (section 5).
5. Backfill `delivery_fee_final_vnd = delivery_fee_vnd` and `delivery_fee_set_at = status_changed_at` for rows now `Finished` (the fee fixed at order time was the fee paid). Open rows get nothing.
6. Set the `status` column default to `Received` (the old default `New` would violate the new CHECK) [v1.3 | 2026-11-02]; add the new CHECKs, the open-list index `customer_order_open_list_idx` (order-process.md section 4), the tables of sections 2 and 6 with their indexes.
7. Create the function `order_record_insert_only` and the insert-only triggers (section 7, b).
8. Recreate the guard (pairs of order-process.md section 2), the capacity release (releases on `Cancelled`, event writes as before) and the immutable function.
9. Verify block: row count equal to step 1; no row has an old status; both insert-only triggers and the `order_fee_correction` CHECKs exist (migration aborts otherwise).

Compatibility: not additive; stop the old backend, apply, start the new backend (ADR-0033, Old clients). The sample seed (`backend/db/seed/sample.sql`) still uses the old status words; it changes in slice S2 or later, not in the slice that adds 0008 [v1.3 | 2026-11-02].

## 4. Rows that drive the migration check [v1.1 | 2026-11-02]

Step 7 counts `customer_order` only. Step 1 stops writing events during the remap: the remap is a plain UPDATE of `status`, and the recreated guard is not fired for it because it is dropped. No `order_event` row is written for the remap (no real transition happened).

## 5. `order_event` after 0008: exactly what is touched [v1.1 | 2026-11-02]

| Object | Action in 0008 |
| ------ | -------------- |
| Rows of `order_event` | Untouched. Old rows keep `New`, `Confirmed`, `Completed`, `Cancelled` forever; new rows use the six new words |
| Trigger `order_event_append_only` (0001, replaced in 0006) | Untouched |
| `order_event` CHECKs | No CHECK names status words (0001 has only `event_type` and `actor_type`; 0003 has `reason` values and `reason only when to_status = 'Cancelled'`), so none is dropped or added. `event_type` stays `created`, `status_changed` |
| Trigger `customer_order_status_guard` | Dropped, recreated with the new pairs (no event write inside it) |
| Trigger `customer_order_release_capacity` | Dropped, recreated; the event insert it makes uses the new words |
| `customer_order` status CHECK | Replaced by the six values |

Legacy mapping on read (one shared function, API side, and the apps for unknown words): `New` to Received, `Confirmed` to Processing, `Completed` to Finished; `Cancelled` and the new words as they are. The history in the order detail shows the mapped label; the stored word is never changed. Date moves are rows of `order_expected_date_change`, not `order_event` rows; the history is the merge of both by time. A fee entry is part of the `DeliveryDateScheduled` to `DeliveryStarted` event (the fee is stored on the order with `delivery_fee_set_at`).

## 6. Fee correction record and date rule [v1.2 | 2026-11-02]

New table `order_fee_correction` in the same file 0008 (one numbered file, forward-only, `pg_dump` first, nothing in 0001 to 0007 edited; FR-30, BR-17):

| Column | Type | Rule |
| ------ | ---- | ---- |
| id | bigint identity | PK |
| order_id | uuid | FK `customer_order`, ON DELETE RESTRICT |
| old_fee_vnd | integer not null | CHECK 0 to 10 000 000 |
| new_fee_vnd | integer not null | CHECK 0 to 10 000 000; CHECK `new_fee_vnd <> old_fee_vnd` |
| changed_by_account_id | uuid null | FK `account`; null if the account is removed (name kept) |
| changed_by_name | text not null | Account name snapshot (`app.actor_name`) |
| changed_at | timestamptz | default now() |

Index `(order_id, id)`. Insert-only: a trigger refuses UPDATE and DELETE (same function as `order_expected_date_change`). Insert and fee update run in one transaction.

Replacement of `customer_order_immutable` (step 6): `delivery_fee_final_vnd` may change only when OLD.status = NEW.status = `DeliveryStarted` and OLD value is not null (correction), or when the status changes `DeliveryDateScheduled` to `DeliveryStarted` (first entry). Any change of `delivery_fee_final_vnd` or `expected_delivery_date` on a row whose OLD.status is `Finished` or `Cancelled` raises an exception. Fee stays CHECK 0 to 10 000 000.

Date range rule: today to today + 7 is enforced by the API only (needs the Vietnam calendar date at request time; a CHECK cannot use the clock). No column or setting is added for it; the table `order_expected_date_change` records every accepted value.

Customer lookup (ADR-0034 v1.2, api/10): no new table or column; the cake lines come from `customer_order_item` by the lateral aggregate in api/10 10.14.3. It reads `customer_order` by `customer_phone` with the existing index `(customer_phone, created_at)` and `status_changed_at` for the 30-day window; rows with a purged phone never match.

Step 9 of the migration checks that the table `order_fee_correction` exists with its CHECKs and trigger.

## 7. As written in 0008 [v1.3 | 2026-11-02]

Confirmed against `backend/db/migrations/0008_order_process.sql` (forge-dev):

- (a) `customer_order_open_idx` (0003) is dropped; `customer_order_open_list_idx` on `(shop_id, COALESCE(expected_delivery_date, delivery_date), slot_start_time, created_at, id)` with the four open statuses replaces it.
- (b) `order_record_insert_only` refuses every DELETE and UPDATE except one: `changed_by_account_id` set to NULL with every other column equal (`to_jsonb` comparison), because `ON DELETE SET NULL` of a removed account is an UPDATE. The name snapshot stays.
- (c) `status` default becomes `Received`.
- (d) New columns are added before the Finished backfill.
- (e) The immutable function is the binding rule, stricter than section 6 text before v1.3: `delivery_fee_final_vnd` changes only on the status change `DeliveryDateScheduled` to `DeliveryStarted` (first entry) or in `DeliveryStarted` to `DeliveryStarted` when the old fee is not null (correction); any change of fee or expected date when OLD.status is `Finished` or `Cancelled` raises; `cancel_reason` and `pii_purged_at` rules of 0003 stay.
- Seed: see Compatibility above.

## 9. Indexes after 0008: is a window index still needed? [v1.5 | 2026-11-02]

Question from forge-dev: after 0008 only `customer_order_open_list_idx` remains. Answer: no, a second index remains and none is added (no 0010). 0008 drops only `customer_order_open_idx` (0008 line 21); `customer_order_shop_created_idx ON (shop_id, created_at)` from 0003 line 55 is untouched. Use: the open view, the badge and the red marks read `customer_order_open_list_idx` (partial, four open statuses, list date first); the final orders of the 90-day window (`status IN (Finished, Cancelled)` and `created_at >= now - 90 x 24 hours`, ADR-0029) and every search over that window read `customer_order_shop_created_idx`; the search itself is a `search_fold` scan of the rows that range yields (a few thousand at most, ADR-0029). The test that expected the old `customer_order_open_idx` by name (`OrderMigrationTests`, 0003) must expect `customer_order_shop_created_idx` only; that is a test fix for forge-dev, not a schema change. Rule kept: any later index or column change is a numbered migration with a `pg_dump` backup step first (the database-change rule); none is needed now.

## 8. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.5 | 2026-11-02 | Section 9: window index still exists, no migration 0010. |
| 1.4 | 2026-11-02 | Plan split into 0008 and 0009 (data-model/07); lookup reads items in one statement, no schema change. |
| 1.3 | 2026-11-02 | Document matches 0008 as written: step order, old open index dropped, status default, insert-only function, stricter immutable rule (section 7). |
| 1.2 | 2026-11-02 | Table `order_fee_correction`, stricter immutable trigger, date range rule (API only), no new structure for customer lookup. |
| 1.1 | 2026-11-02 | `order_event` is not remapped (append-only kept); legacy words mapped on read; sections 4 and 5. |
| 1.0 | 2026-11-02 | First version. |
