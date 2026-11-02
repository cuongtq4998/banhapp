# Admin Orders Test Plan: List, Badge, Migration, Settings (part 15)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.1). Holds: sections 4.23 to 4.25 (new in v2.1 [v2.1 | 2026-11-02]), tests for FR-9, FR-10, FR-13, FR-14, FR-23, BR-9, BR-11, AC-37, AC-40, AC-41, AC-52 and the migration of old statuses. Level key: see [part 13](13-order-process-matrices.md). Cases TC-B401 to TC-B458, TC-C401 to TC-C416. Early mode: `Not run`. Fixed today 10/11 (Vietnam time). List date = expected date when set, else requested date (BR-9).

## 4.23 List, badge, red marks, order (FR-9, FR-10, FR-13, BR-9, AC-52)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B401 | acceptance | API | AC-52, FR-9 | One open order per step R, P, S, D, all list date 10/11 or earlier | Default list "To do" holds all four; each carries due or overdue mark; F and X orders absent |
| TC-B402 | acceptance | API | AC-52, FR-13 | Same data; read the unfinished count | 4; F and X add nothing |
| TC-B403 | acceptance | API | AC-52, BR-9 | Order requested 10/11, expected 12/11 (S) | List date 12/11: no red mark today, not counted, sorted as 12/11 |
| TC-B404 | acceptance | API | AC-52 | Same order on 12/11 (clock moved) | Due today, red, counted |
| TC-B405 | acceptance | API | BR-9 | Requested 08/11, expected 12/11, today 10/11 | Not overdue (expected date wins over an older requested date) |
| TC-B406 | acceptance | API | BR-9 | Requested 12/11, expected 08/11 (earlier than requested), today 10/11 | Overdue 2 days (expected date wins even when earlier) |
| TC-B407 | boundary | API | BR-9, FR-9 | List date = today, today minus 1, today plus 1 for each of R, P, S, D | Mark "due today", "overdue 1 day", no mark; count only the first two |
| TC-B408 | acceptance | API | BR-9 | R and P orders have no expected date | They use the requested date |
| TC-B409 | acceptance | API | BR-9 | Order of list date 10/11 moves to 20/11 by A2 | Mark and count disappear in the next list and count read |
| TC-B410 | acceptance | API | BR-9 | Order of list date 20/11 moved back to 09/11 | Overdue 1 day appears; count +1 |
| TC-B411 | acceptance | API | BR-9 | A requested 10/11 slot 08:00 (R), B requested 12/11 expected 10/11 slot 12:00 (S), C requested 10/11 slot 08:00 placed earlier (P) | Order by list date, slot, placed time: C, A, B; stable |
| TC-B412 | extra | API | BR-9 | Same list date; slot of the requested date used for ties (expected date has no slot) | Recorded (question Q-P6) |
| TC-B413 | boundary | API | FR-13 | 98, 99, 100, 101 unfinished orders | Count numeric as is; clients show "99+" above 99 |
| TC-B414 | acceptance | API | FR-13 | Finish the last unfinished order | Count 0, hidden |
| TC-B415 | acceptance | API | FR-10 | Filter by each status: To do, R, P, S, D, F, X, All | Exact members; "To do" is R+P+S+D |
| TC-B416 | negative | API | FR-10 | Filter by old names `new`, `confirmed`, `completed` and an unknown status | 400 or empty; never silently All |
| TC-B417 | acceptance | API | FR-10, BR-9 | Date filter today, tomorrow, one date, with S orders whose expected and requested dates differ | Uses the list date (expected when set); if the api uses the requested date, record in Q-P6 |
| TC-B418 | boundary | API | BR-9 | F and X orders placed 89, 90, 91 days ago | Shown at 89 and exactly 90; not listed, searched or opened at 91 |
| TC-B419 | extra | API | BR-9 | Open S order placed 400 days ago, expected date today | Still shown (open orders exempt) |
| TC-B420 | extra | API | BR-9 | 120 open orders; page 1 and 2 | 50 per page; no duplicate or gap; stable when one order changes between pages |
| TC-B421 | extra | DB | BR-9 | 10 000 orders in all statuses, default list and count | List under 1 s; count agrees with list |
| TC-B422 | extra | API | FR-9 | Row fields at each step | Code, name, status, date and slot, cakes, cake total, district; no fee, no phone |
| TC-B423 | extra | API | FR-9 | Row of an S order | Shows the expected date as delivery date or both per design (record) |
| TC-B424 | extra | API | BR-9 | Clock at 23:59 and 00:00 Vietnam time with list date = that day | Mark flips at Vietnam midnight |
| TC-B425 | extra | API | FR-10 | Search by order code or phone for orders in each step | All found; F and X within 90 days found |
| TC-C401 | acceptance | iOS, Android | AC-52 | List with four open orders and an F and an X | Four rows with red marks per list date; F and X only under their filters |
| TC-C402 | acceptance | iOS, Android | AC-52 | S order requested 10/11 expected 12/11, today 10/11 | No red mark; date shown per design |
| TC-C403 | acceptance | iOS, Android | FR-13 | Badge with 0, 1, 99, 100 unfinished | Hidden, 1, 99, "99+" |
| TC-C404 | acceptance | iOS, Android | FR-10 | Filter control shows the eight values with Vietnamese labels | All eight; selection kept on return from detail |
| TC-C405 | acceptance | iOS, Android | FR-13 | After A2 moves an order to a future date | Badge and mark update on return to the list |
| TC-C406 | extra | iOS, Android | FR-9 | Longest status label at the largest text size, narrow phone | Readable, no clipping |
| TC-C407 | extra | iOS, Android | FR-9 | Clock and zone changed on the device | Marks follow the server date |

## 4.24 Migration of existing rows (Q-36 assumption)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B431 | acceptance | DB | Q-36, BR-2 | Seed New, Confirmed, Completed, Cancelled (200 rows, all dates); run the migration | New to Received, Confirmed to Processing, Completed to Finished, Cancelled unchanged; counts per status equal |
| TC-B432 | acceptance | DB | Q-36 | Code, customer, cakes, totals, requested date, slot, notes, cancel reasons | Equal before and after |
| TC-B433 | acceptance | DB | BR-3 | Old status records (New to Confirmed, Confirmed to Completed, cancels) | Kept with the new names, original time and account |
| TC-B434 | acceptance | DB | BR-11, AC-41 | Old orders stored a district fee and a total | Atlas decides: fee kept as real fee or dropped; displayed amounts do not change silently (question Q-P7) |
| TC-B435 | acceptance | DB | BR-15 | Old orders have no expected date | Empty; list date = requested date; marks unchanged |
| TC-B436 | acceptance | DB | BR-9 | Old Confirmed order due 08/11 | Processing, still overdue, in count and "To do" |
| TC-B437 | acceptance | DB | BR-2 | Old Completed order that never "started delivery" | Finished, no expected date; no action offered; fee display per Q-P7 |
| TC-B438 | acceptance | DB | AC-28 | Old Confirmed (now Processing) cancelled; old Completed cancel attempt | First works and returns capacity; second refused |
| TC-B439 | extra | DB | Q-36 | Run the migration twice | No change on the second run; no error |
| TC-B440 | extra | DB | Q-36 | Run on an empty database and on one with only Cancelled rows | No error |
| TC-B441 | extra | DB | Q-36 | Orders placed during the migration | New vocabulary or briefly blocked; none lost |
| TC-B442 | extra | DB | Q-36 | Rollback or restore of the migration (if the dev guide has one) | Old statuses return with same counts; or "not supported" recorded |
| TC-B443 | extra | API | Q-36 | Old client sends `confirmed` after migration | Refused with a clear message; recorded |
| TC-B444 | extra | API | Q-36 | Notification queued before migration with "new order" text | Delivered; tap opens the order in Received |
| TC-B445 | extra | DB | Q-36 | Per-phone limit of 5 before and after | Same counts per phone |
| TC-B446 | extra | DB | Q-36 | Day load per date before and after | Unchanged |

## 4.25 Delivery settings and estimated fee (FR-23, BR-11, AC-37, AC-40, AC-41)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B451 | acceptance | API | AC-37 | Add district "Quan Mau" estimate 25 000; read the customer district list | Offered with 25 000 labelled estimate; no total includes it |
| TC-B452 | acceptance | API | AC-37 | Change to 30 000 | New readers see 30 000; existing orders unchanged |
| TC-B453 | acceptance | API | AC-37 | Switch off; read customer list and old orders; switch off the last active district | Gone for new orders, old orders still show it; last district refused |
| TC-B454 | boundary | API | AC-40, BR-11 | District estimate 0, 1, 10 000 000, 10 000 001, -1, 12.5 | 0, -1, 12.5, 10 000 001 refused; 1 and 10 000 000 accepted |
| TC-B455 | acceptance | API | AC-40 | Price 0, limit 0, limit 10 000, empty shop name, 301-character greeting | Each refused naming the field; nothing stored |
| TC-B456 | extra | API | BR-11 | Real fee minimum 0 versus estimate minimum 1, sent to the wrong endpoint | Each range enforced on its own field only |
| TC-B457 | extra | API | FR-23 | Estimate saved with another field invalid | Whole form refused; estimate unchanged |
| TC-B458 | extra | API | FR-23 | Two owner phones save different estimates for one district | Same rule as TC-B143; no mixed state |
| TC-C411 | acceptance | iOS, Android | AC-37 | Delivery settings label the fee "estimated fee" with help text on the real fee | Vietnamese copy per design; no "fee charged" wording |
| TC-C412 | acceptance | iOS, Android | AC-40 | Enter 0 in the estimate field | Refused naming the field |
| TC-C413 | acceptance | iOS, Android | AC-37 | Add, rename, off, on for a district | As TC-C29 with the estimate wording |
| TC-C414 | extra | iOS, Android | FR-23 | Staff opens the app | No Delivery settings (owner only) |
| TC-C415 | extra | iOS, Android | AC-41 | Detail of an old order after the estimate changes | Stored fee and total unchanged |
| TC-C416 | extra | iOS, Android | AC-37 | Estimate input at 10 000 000 and 10 000 001 | Accepted, refused with message |
