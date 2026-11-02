# Admin Orders Test Plan: Migration 0008, Backup Rehearsal, Trace, Questions (part 19)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.2). Sections 4.32 to 4.34 (new in v2.2 [v2.2 | 2026-11-02]) for data-model/06 v1.2 steps 1 to 7, ADR-0033 v1.2, ADR-0034, PRD place-order v1.9 and admin-orders v1.12. Early mode: all `Not run`. Complements TC-B401 to TC-B458 in part 15; ids here add to them.

## 4.32 Migration 0008 with old rows (FR-17, data-model/06 sections 3 and 5)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B701 | acceptance | API+DB | data-model/06 | Database at 0007 with orders in New, Confirmed, Completed, Cancelled (each with items, fee estimate, total); apply 0008 | Migration succeeds; no row lost (count equal); mapped to the six names per Q-36 assumption; `CHECK` has six values |
| TC-B702 | acceptance | DB | data-model/06 s5 | `order_event` before and after: row count, ids, content checksum | Untouched (no UPDATE of old rows); legacy words remain in old events; new events use the six names |
| TC-B703 | acceptance | API | api/10 10.14.1 | Read old rows through admin detail, list and customer lookup after the migration | Status shows a six-word name; legacy words never in API output; old events render with mapped words on read |
| TC-B704 | extra | API+DB | data-model/06 | Old Finished order (never passed Delivery started): fee fields null | Detail shows the estimate and "no real fee" per Q-P7 answer; no crash; the stored estimate and total unchanged |
| TC-B705 | extra | DB | data-model/06 | Old rows keep estimate, total and total CHECK; the immutable trigger replaced | Direct UPDATE of estimate or total refused; the new stricter rules of TC-B541 to TC-B543 apply to migrated rows |
| TC-B706 | extra | DB | data-model/06 | Migration run twice, and on an empty database | Second run refused or no-op by the numbered runner; empty database ends in the same schema as migrated |
| TC-B707 | extra | DB | data-model/06 step 7 | Post-checks: `order_fee_correction` exists with CHECKs, FK, insert-only trigger, index `(order_id, id)`; capacity release and guard recreated | All exist; a Cancelled move releases capacity as before |
| TC-B708 | extra | DB | data-model/06 | Migration with an open order whose status changes by another session during it | Blocked by lock or consistent result; none left in a legacy word |
| TC-B709 | extra | DB | ADR-0034 | Index `(customer_phone, created_at)` exists and the lookup query uses it (`EXPLAIN` on 100 000 fake rows) | Index scan, not sequential; recorded timing |
| TC-B710 | extra | DB | rule 15.1 | Files 0001 to 0007 are byte-identical to the commit before; 0008 is one numbered forward-only file | Checksums equal; no edit of earlier migrations |

## 4.33 Backup and restore rehearsal (ops check, not CI)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-O701 | ops | Ops | data-model/06 s3 | On a disposable PostgreSQL with fake data at 0007: `pg_dump --format=custom` with the migration URL; name has database, date, last migration `0007`; store outside the repository | Dump file exists; name follows the rule; not under the repository tree; no secret in the name |
| TC-O702 | ops | Ops | data-model/06 s3 | Restore the dump into an empty database, then compare table row counts and checksums with the source | Equal; restore needs no manual step |
| TC-O703 | ops | Ops | data-model/06 s3 | Apply 0008 to the restored copy, run TC-B701 to TC-B707 | Pass; the source database untouched |
| TC-O704 | ops | Ops | data-model/06 s3 | Recovery: after a failed 0008 (forced error at step 5), restore the dump | Database back at 0007 state; app of the previous version works |
| TC-O705 | ops | Ops | rule 15.1 | The deploy job order: backup before migrate, abort on dump failure | Pipeline text reviewed: no migration step runs without a successful dump; record the file and line |
| TC-O706 | ops | Ops | PO rule | Dump handling: encrypted at rest, not in CI artifacts of a public run, no real data | Checked by review of the job and storage settings; Blocked if the host is not available |

## 4.34 Trace, ids without tests, questions

| Id | Tests |
| -- | ----- |
| FR-28, AC-49, BR-15 (range) | TC-B501 to TC-B517, TC-C501 to TC-C503 |
| FR-30, BR-17, AC-53 | TC-B521 to TC-B548, TC-C521 to TC-C525 |
| FR-22 to FR-27, AC-38 to AC-47, BR-16 to BR-18 (API) | TC-B601 to TC-B639; UI in place-order part 10 (TC-P201 to TC-P232) |
| AC-48 | TC-B613 to TC-B615, TC-B627, TC-P222 |
| AC-54, BR-16 (refusal at the door) | TC-B246 and part 13 (no Cancel after S); no test for "handled outside the app" (no behaviour) |
| Migration 0008 | TC-B701 to TC-B710, TC-O701 to TC-O706 |

Ids with no test: BR-16 admin-orders "handled outside the app" (no system behaviour); "may move by a few days" wording (text only, UI copy check TC-P206); the "shop contact" content (catalog, tested with the catalog).

| ID | To | Question or finding |
| -- | -- | ------------------- |
| Q-P2 | requirements | Answered by FR-30 (correction while D); the question is closed for the fee. TC-B313 expects a D order with a different fee through the status route to be refused, correction only via PUT: confirm (atlas). |
| Q-P9 | atlas | Same cursor and rate-limit counter: does page 2 count one lookup (api/10 says yes). A user paging 5 pages uses 5 of 10 hourly lookups; with a refresh (FR-26) the budget is small. Intended? (requirements) |
| Q-P10 | requirements | Window edge: "30 days after Finished" is it `<= 30 x 24 h` or by calendar day in Vietnam? TC-B622 needs the exact rule. |
| Q-P11 | atlas | Which header names the client address when behind a proxy (ADR-0019)? TC-B631 cannot be fixed without it. |
| Q-P12 | atlas | The 250 ms floor: a slow non-empty query exceeds it and leaks by timing under load. Accepted residual (TC-B615)? Confirm with the owner as a security consequence. |
| Q-P13 | requirements | Victim budget exhaustion (TC-B632) is a denial of the customer feature by anyone knowing a phone; stated in ADR-0034 as accepted. Confirmation by the owner that it is in the PRD (BR-17 place-order) is missing in the AC text. |
| Q-P14 | atlas | `FEE_UNCHANGED` versus 409 order: api/09 table lists both for "equal to stored" when previous also equals; the order of checks (TC-B533, TC-B534) is not stated. |
| DOC-6 | atlas | api/09 10.13.1 says date range check uses "shop today"; the time source (server clock, configuration of the zone) is not stated; TC-B507, TC-B508 assume Asia/Ho_Chi_Minh fixed offset. |
| DOC-7 | requirements | Place-order AC-44 text mixes "hourly limit" numbers (not stated) with api/10 (10, 30, 20 per hour); AC needs the numbers or a pointer. |
| DOC-8 | atlas | api/10 lists no `fee_corrections` and no date history in the answer (good); data-model/06 should state that `delivery_fee_final_vnd` after correction is the only value exposed. Wording only. |

Test needs for developers: a clock control for the Vietnam date (TC-B507 to TC-B510, TC-B622, TC-B628), configuration overrides for limits, page size and retention (`LOOKUP_*`), a log capture hook, a PostgreSQL test database, seed fixtures for old statuses at 0007, and a disposable PostgreSQL for TC-O701 to TC-O704.
