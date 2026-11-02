# Data Model: order process columns and migration 0008

Part of [data-model.md](../data-model.md). Version 1.1 [v1.1 | 2026-11-02]. Traces: BR-2, BR-9, BR-11, BR-15, FR-28, FR-29, AC-49 to AC-52; ADR-0033.

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

## 3. Migration plan: `backend/db/migrations/0008_order_process.sql`

Forward-only; 0001 to 0007 are never edited (policy 15.1 in data-model/05).

Before applying (operator, rule 15.1 steps 4 to 6): take `pg_dump --format=custom` with `DATABASE_MIGRATION_URL`, name it with database, date and last migration `0007`, store it encrypted outside the repository, test-restore once. The deploy job does not apply 0008 without it. Rollback is a restore of that dump (no down script).

Steps, one transaction:

1. Drop triggers `customer_order_status_guard` and `customer_order_release_capacity` (also stops `order_event` writes during the remap).
2. Drop the `status` CHECK.
3. Remap `customer_order.status` only: New to Received, Confirmed to Processing, Completed to Finished, Cancelled unchanged. `order_event` is NOT touched [v1.1 | 2026-11-02]: no UPDATE, no trigger disabled (section 5).
4. Backfill `delivery_fee_final_vnd = delivery_fee_vnd` and `delivery_fee_set_at = status_changed_at` for rows now `Finished` (the fee fixed at order time was the fee paid). Open rows get nothing.
5. Add the three columns, the new CHECKs, table and index of section 2, the open-list index of order-process.md section 4.
6. Recreate the guard (pairs of order-process.md section 2), the capacity release (releases on `Cancelled`, event writes as before) and the immutable function.
7. Verify block: `SELECT status, count(*)` before and after equal in total; no row has an old status (migration aborts otherwise).

Compatibility: not additive; stop the old backend, apply, start the new backend (ADR-0033, Old clients). Sample seed (`backend/db/seed`) statuses are updated by forge-dev in the same change.

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

## 6. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.1 | 2026-11-02 | `order_event` is not remapped (append-only kept); legacy words mapped on read; sections 4 and 5. |
| 1.0 | 2026-11-02 | First version. |
