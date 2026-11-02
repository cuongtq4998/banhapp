# System Architecture: Slices B2 and B3 alignment, document corrections, open defects

Part of [architecture.md](../architecture.md) (index, version, change log), section 27. New in v1.15 [v1.15 | 2026-11-01]. Slices B2 (order list, search, detail) and B3 (status change, cancel reason, per-phone rule) are built; where the code was the better choice the system documents now follow it. Sources read: `backend/Sources/App/Routes/Admin/AdminOrderRoutes.swift`, `Services/Admin/Orders/*`, `Repositories/Admin/AdminOrder*.swift`, `Repositories/PostgresOrderRepository.swift`, `backend/db/migrations/0003_admin_orders.sql`, `backend/Tests/AppTests/Admin`, `contracts/fixtures/admin`. Format as in [10-b1-alignment.md](10-b1-alignment.md).

## 27.1 Decisions and corrections

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| Search minimum | `q` is 3 to 50 characters after trim and NFC (3 digits for a phone-like text). The PRD (BR-10) always said 3; api/06, ADR-0029 and architecture/08 TQ-D7 said 2 and are corrected | api/06 10.9, ADR-0029 v1.5, architecture/08 |
| Search matching | Substring on order code (with or without `BT-`), name (SQL function `search_fold` = `lower(unaccent())`, plain `lower()` when the host refuses the extension) and phone digits (`0` read as `84`); `%` and `_` in `q` are literal; control characters are refused | ADR-0029 v1.5, api/08 11.1 |
| Cursor | Opaque to clients; a cursor the server cannot read is 422 `CURSOR_INVALID`; the encoding may change | api/06 10.9, api/08 11.1, ADR-0029 v1.5 |
| Field codes | `UNKNOWN_PARAMETER`, `REPEATED_PARAMETER`, `STATUS_INVALID`, `DATE_INVALID`, `DATE_PRESET_INVALID`, `DATE_FILTER_CONFLICT`, `SEARCH_INVALID`, `CURSOR_INVALID` (list); `UNKNOWN_FIELD`, `STATUS_INVALID`, `REASON_NOT_ALLOWED` (status change). Their `message_key` is `ERR_SERVER` | api/08 11.1, api/06 10.11 |
| Capacity trigger | No `GREATEST` floor. A cancel subtracts `total_cakes` from the order's `day_load` row; a missing row is not touched; the CHECK `cakes_accepted >= 0` is the only guard; a repeated cancel changes nothing | data-model/05 section 11, data-model/03, ADR-0030 v1.2 |
| Per-phone rule | `created_at` in the last 24 hours AND `(status <> 'Cancelled' OR cancel_reason = 'fake_spam')`; api/03 step 7, api/01, auth/abuse, ADR-0014 v1.3, data-model/02 and 05 already agreed; ADR-0030 text on "built" state corrected | ADR-0030 v1.2, data-model/05 |
| Migration name | `0003_admin_orders.sql` holds section 11 only; the cake and settings changes (sections 12, 13) come in a later file. Documents said `0003_admin_orders_catalog.sql` | data-model/05 section 15, ADR-0030 v1.2 |
| Rate limits | `GET /v1/admin/orders` and the detail count against the shared per-address read budget (global middleware); the status `POST` has no limit of its own | api/06 10.9 |
| Status body | Order of checks as ADR-0028: role, window lookup (404), body fields (422), allowed pair (422 with `details.status`), compare-and-set. `cancel_reason: null` with a non-cancel target is accepted; a cancel without a valid reason is `CANCEL_REASON_REQUIRED` (no fields) | api/06 10.11, ADR-0028 v1.4 |
| Detail | Items are sorted by `product_name`, then product id; `last_change.at` is the last event time (the `created` event when nobody changed the order); `allowed_actions` is `confirm, cancel` for New, `complete, cancel` for Confirmed, empty when final | api/06 10.10 |

## 27.2 Not built after B1 to B3

| Item | Decision | Reason |
| ---- | -------- | ------ |
| Purge task (codes, sessions, security events) | BUILT after B3 [v1.21 | 2026-11-02] in `Services/Admin/Auth/Maintenance` (`MaintenancePolicy`, `MaintenancePurge`, `MaintenanceScheduler`); not in B2 or B3 themselves. Not started under `APP_ENV=testing`. NOT yet verified: `MaintenancePurgeTests` have not run against PostgreSQL (no database on the dev host) and the session and security-event deletes have no test. Go-live gate stays open until the tests pass in CI or locally | `auth_code` rows hold addresses; harmless on the free staging host with fake data only (architecture/10 26.2, data-model/05 section 14) |
| Push to phones, `PUT /v1/admin/push-token` | Built in slice B7 (architecture/14) [v1.18 | 2026-11-01] | FR-25, FR-26 |
| Review-account sign-in and `review-account on/off` | Deferred to the launch slice A6; BUILT later, see architecture/16 [v1.20 | 2026-11-01] | Store submission waits for the money approvals; demo rows exist in the schema only |

## 27.3 Other document and code differences found (B1 to B3)

| Item | Finding | Resolution |
| ---- | ------- | ---------- |
| data-model/05 migration file name | `0003_admin_orders_catalog.sql` in two places | Fixed (27.1) |
| ADR-0030 | Said migration 0003 "is not built yet" and that the slice 3 rule "counts any status" | Fixed (v1.2) |
| api/06 10.9 error line | Said repeated `status` is an unknown parameter | Fixed: repeated is `REPEATED_PARAMETER`; `date_from`, `date_to`, `view` are `UNKNOWN_PARAMETER` |
| B1 documents | Aligned in architecture/10. This round re-read only what B2 and B3 touch (role gate on the order routes, rate limits, error envelope); no further differences found there | None |
| Dev guide | The paragraph for B2 and B3 matches the code; it is owned by forge-dev and was not edited | None |

## 27.4 Defects for forge-dev (code differed from the documents; the documents are the contract). Both fixed in B6 [v1.17 | 2026-11-01], see [13-b6-alignment.md](13-b6-alignment.md) section 29.2

| ID | Defect | Expected | Evidence |
| -- | ------ | -------- | -------- |
| | Status | | Both D-1 and D-2: fixed in B6 (migration `0005`, `changeStatus`). The rows below are the original findings |
| D-1 | `POST /v1/admin/orders/{code}/status` looks the order up through the window before the replay test. An exact repeat (same account, same move) of the change that closed an order placed more than 90 days ago answers 404 `ORDER_NOT_FOUND` | 200 with `Idempotent-Replay: true` and the current detail (FR-19: a repeat is not an error; ADR-0028 v1.3, R-1; test cases TC-B68, C23, C38). Any other call on an order outside the window stays 404, and 409 `details.order` is never built for it | `AdminOrderService.changeStatus` calls `find(code:window:)` first; `OrderStatusTests.testAnOldOpenOrderCanBeClosedAndThenLeavesTheWindow` asserts 404 for the repeat and must change |
| D-2 | The trigger `customer_order_release_capacity` subtracts cakes for a cancelled order even when `is_demo` is true, although demo rows are excluded from `day_load` | Skip the `day_load` update when `OLD.is_demo` (new migration, forward-only). Matters once the review account (slice A6) can cancel a demo order; no effect before | `0003_admin_orders.sql` trigger body; data-model/05 `is_demo` row |

Neither defect changes the PRD. Query for the requirements agent: none. Query for forge-dev: none left (D-1 and D-2 fixed in B6).
