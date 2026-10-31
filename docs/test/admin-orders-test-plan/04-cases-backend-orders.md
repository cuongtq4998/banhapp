# Admin Orders Test Plan: Backend cases, orders, notifications, repeat-order limit (part 04)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: TC-B53 to TC-B100. Same columns as [part 03](03-cases-backend-auth.md). Every result is `Not run`. [v1.0 | 2026-10-31]

## 4.5 List, search, paging (FR-8 to FR-12, FR-41, BR-13)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B53 | acceptance | AC-15 | Seed A New 02/11, B Confirmed 01/11, C Completed 01/11, D New 01/11 placed before B; default list | Order D, B, A; C absent. Repeat with filter Completed+Cancelled: same sort rule (BR-13) |
| TC-B54 | acceptance | AC-16 | Open list row data | Code, name, status, date, slot, cake count, total, district present and match stored values |
| TC-B55 | acceptance | AC-17 | Four orders, one per status; filter Cancelled; filter all; filter New+Confirmed together; unknown status value | Only the chosen statuses; unknown value refused (400), not "all" |
| TC-B56 | acceptance | AC-18 | Orders 01/11, 02/11, 05/11, today 01/11: today, tomorrow, range 01/11-02/11, one date | Matches AC-18; range with end before start refused |
| TC-B57 | edge | AC-18, A-1 | Clock 2026-11-01T16:59:59Z (23:59:59 shop) and 17:00:00Z (00:00 next day shop) | "today" flips at 00:00 UTC+7, not at UTC midnight |
| TC-B58 | acceptance | AC-19 | Order BT-AAAAAA, "Tran Thi B", +84 900 000 010; search `AAAAAA`, `Thi B`, `0900000010`, `zzz` | First three find it; `zzz` empty |
| TC-B59 | extra | FR-11 | Search `%`, `_`, `\`, `'; --`, `+84900000010`, `0900 000 010`, `thi b` (case), `Thị B` (diacritics), 1 character, 200 characters | Wildcards are literal; no 500; phone formats find the order; case-insensitive; behaviour for diacritics and short terms recorded (R-13) |
| TC-B60 | acceptance | AC-20 | 3 New orders, count 3; a customer orders; refresh | Count 4; list has the new order. Count ignores list filters; excludes orders older than 90 days |
| TC-B61 | acceptance | AC-23 | 120 matching orders; fetch pages | 50, 50, 20; no duplicate and no gap; last page has no next marker |
| TC-B62 | extra | AC-23 | Between page 1 and 2: a new order arrives; another order changes status out of the filter | No duplicates; no crash; whether a row is skipped is recorded (R-14) |
| TC-B63 | negative | AC-23 | Page size 0, -1, 1000, text; forged, expired or other-user cursor | Validation error or clamp to 50; never an unbounded list; no 500 |

## 4.6 Detail and status changes (FR-14 to FR-20, BR-2 to BR-4)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B64 | acceptance | AC-24 | Order of 2 cakes, then cake price changed; open detail | All FR-14 fields; stored price and fee, not the new ones; note and cancel reason when present |
| TC-B65 | acceptance | AC-26 | Staff A confirms a New order | Confirmed; history entry with account name; list shows the new status |
| TC-B66 | acceptance | AC-27 | Complete a Confirmed order due in 5 days; complete a New order | First Completed (final); second refused and stays New |
| TC-B67 | acceptance | AC-28 | Limit 100, 98 accepted for 05/11, New order of 4 cakes; cancel with "day full"; ask availability for 6 cakes | Cancelled; `cakes_accepted` is 94; availability says 6 fits |
| TC-B68 | negative | AC-29 | Cancel with no reason, empty reason, unknown reason, reason in other case/language, 2 reasons | Refused; order unchanged; capacity unchanged |
| TC-B69 | acceptance | AC-29, AC-69 | Read the allowed reasons; cancel a New and a Confirmed order with each of the five | Exactly 5 values; stored and shown in detail and history |
| TC-B70 | acceptance | AC-30 | Staff A and B hold New order; A confirms; B cancels with a stale view | B refused; order Confirmed; response carries current status and a Vietnamese message |
| TC-B71 | negative | AC-30, BR-2 | All 16 status pairs (4 from x 4 to), with a fresh view | Only the 4 allowed pairs succeed; every other pair refused, stored order unchanged; also by direct SQL (trigger) |
| TC-B72 | extra | FR-19 | Reason: double tap and retry. Same Confirm sent twice (same stale view, then fresh view) | One history entry only; the second answer is defined (idempotent success or stale refusal) and is not a 500 (R-8) |
| TC-B73 | extra | FR-19 | Parallel: A confirms while B cancels the same New order | Exactly one wins; one history entry; capacity released only if cancel won |
| TC-B74 | extra | BR-3 | Parallel: two cancels of one order by two devices | Capacity released exactly once; `cakes_accepted` never negative |
| TC-B75 | extra | BR-3, PO BR-9 | Date at capacity edge: cancel while a customer orders the freed cakes in parallel | Totals never exceed the limit; both outcomes consistent |
| TC-B76 | acceptance | AC-31 | Customer creates, A confirms, owner completes; another with cancel + reason | History oldest first: created by customer, two changes with old/new status, name, time; reason on cancel |
| TC-B77 | negative | BR-4 | Try to update or delete a history entry by API and by direct SQL | No endpoint exists; database refuses |
| TC-B78 | extra | BR-8 | Deactivate staff A, rename not possible; read history | Entries keep A's name; account still named after reactivation |
| TC-B79 | negative | FR-14 | Detail of unknown id, malformed id, id of another type (text, negative number) | 404 / 400 with no internals; same answer for unknown and for older than 90 days |

## 4.7 Order window of 90 days (FR-41, BR-20)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B80 | acceptance | AC-67 | Orders placed 89 and 91 days ago; list, search by its code, filters, detail of each, as staff and as owner | 89 days visible; 91 days never in list or search; direct request refused; same for owner |
| TC-B81 | acceptance | AC-68 | Order placed 89 days ago; clock +2 days; list and detail | Gone from list and detail |
| TC-B82 | edge | BR-20 | Placed 90 d minus 1 s, exactly 90 d, plus 1 s ago; also placed at 23:50 vs 00:10 shop time | Boundary recorded; one rule for list, search, detail, count (R-5) |
| TC-B83 | extra | FR-41 | Status change on an order that is 91 days old (known id); a Confirmed order that ages out | Refused as not found; the order stays Confirmed forever (R-2); capacity unaffected |
| TC-B84 | extra | BR-20 | Owner and staff counts; search by phone matching only an old order | New count and search results exclude old orders; no count leaks their existence |

## 4.8 Notifications (FR-31 to FR-35, BR-14, BR-15)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B85 | acceptance | AC-48 | 3 devices: two registered with push permission, one without a push token; a customer order is stored | Fake provider gets exactly 2 pushes within 60 s; third device sees the order after refresh |
| TC-B86 | acceptance | AC-49 | Order with name "Tran Thi B", +84 900 000 010, address, note | Payload has code, cake count, delivery date; none of name, phone, address, note (also not in data fields) |
| TC-B87 | acceptance | AC-50 | Payload data of the push | Holds the order id/code to open detail; opening after sign-in works; an order older than 90 days is refused |
| TC-B88 | acceptance | AC-52 | Sign out; revoke a device; deactivate an account; then store an order | No push to those devices |
| TC-B89 | extra | FR-35 | Staff A signs out on a phone, staff B signs in on the same phone and push token | Push token is moved to B; A gets nothing on it; token registered twice yields one push |
| TC-B90 | extra | FR-31 | Provider returns invalid token / timeout / 500 | Invalid token is removed; outage does not fail or slow order placement (201 still); no duplicate pushes on retry |
| TC-B91 | extra | FR-31 | Order insert fails/rolls back (validation, capacity) | No push is sent; push only after commit |
| TC-B92 | extra | BR-15 | Run the whole suite with server log capture; grep for the fake names, phones, addresses, notes, codes, credentials | No customer data, code or credential in any log line |

## 4.9 Effect on the place-order limit (FR-44, BR-16)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B93 | acceptance | AC-70 | +84 900 000 010 places 5 orders in 24 h; one cancelled "customer asked"; place a 6th | Accepted |
| TC-B94 | acceptance | AC-71 | Same, cancelled with "fake or spam order" | 6th refused (429 `RATE_LIMITED`) |
| TC-B95 | acceptance | AC-72 | 5 orders: 2 "cannot deliver", 1 spam, 2 open | 2 more accepted, 3rd refused |
| TC-B96 | edge | AC-72 | Orders at 23 h 59 min and 24 h 01 min ago; phone as `0900000010` and `+84900000010` | Window and phone normalisation as for place order; cancelled orders handled the same |
| TC-B97 | extra | BR-16 | Cancel with each of the four non-spam reasons | None counts toward the limit |
| TC-B98 | extra | FR-44 | Cancel a counted order as spam after the customer already hit the limit; place-order per-IP limit (10 an hour) unchanged by cancels; replayed Idempotency-Key | Per-phone count changes immediately; per-IP limit and replay behaviour unchanged. Doc `auth.md` section 4 says cancelled orders count and must be updated (R-10) |
| TC-B99 | extra | NFR | 9 000 orders (100 a day x 90); first list page, search by phone, status change | First page under 3 s; status change under 5 s on the test host (indicative only) |
| TC-B100 | extra | NFR | List with 50 rows: response size, index use (EXPLAIN) | No full scan on filter plus sort at 9 000 rows |
