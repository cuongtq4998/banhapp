# Admin Orders Test Plan: Backend cases, list, status, record, notifications, limit (part 04)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: TC-B49 to TC-B106. Same columns as [part 03](03-cases-backend-auth.md). Every result is `Not run`. Controlled clock; shop date = UTC+7. [v1.1 | 2026-10-31]

## 4.7 To do list, marks, count, filters, search, paging (FR-9 to FR-13, BR-9, BR-10)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B49 | acceptance | AC-14 | Seed A New 02/11, B Confirmed 01/11, C Completed 01/11, D New 01/11 placed before B; default list | Order D, B, A; C absent [v1.1 | 2026-10-31] |
| TC-B50 | extra | AC-14 | Same date and slot, different placed times; same date, different slots; one without slot ties | Sort is delivery date, slot start, placed time, id; stable between calls [v1.1 | 2026-10-31] |
| TC-B51 | acceptance | AC-15 | Read list row data | Code, name, status, date, slot, cake count, total, district present and equal to stored values; no phone, address, note in the row [v1.1 | 2026-10-31] |
| TC-B52 | acceptance | AC-16 | Today 10/11: A New 08/11, B Confirmed 10/11, C New 11/11, D Completed 08/11, E Cancelled 09/11 | Default list A, B, C with A overdue 2 days, B due today, C no mark; status All adds D, E; D and E carry no mark [v1.1 | 2026-10-31] |
| TC-B53 | edge | AC-16 | Clock 2026-11-10T16:59:59Z and 17:00:00Z; month and year boundary; overdue 75 days | Day flips at 00:00 UTC+7; mark text value correct (1 day, 75 days) [v1.1 | 2026-10-31] |
| TC-B54 | acceptance | AC-17 | A, B of AC-16 plus another overdue, C later; then 0 matching; then 120 matching; complete one | Count 3 (C not counted); 0; 120 as a number (client shows 99+); drops by 1 on the next list response after completing [v1.1 | 2026-10-31] |
| TC-B55 | extra | AC-17 | Count with status filter, date filter, search; for staff and owner; an overdue New order older than 90 days; demo orders | Count ignores filters and search; same for both roles; includes the old overdue order; excludes demo orders for real accounts [v1.1 | 2026-10-31] |
| TC-B56 | acceptance | AC-18 | One order per status; each of To do, New, Confirmed, Completed, Cancelled, All | To do = New + Confirmed; others exact; All = four statuses [v1.1 | 2026-10-31] |
| TC-B57 | negative | AC-18 | Unknown status; two statuses together (`New,Cancelled`); removed view value `unfinished`; date range parameters; end before start | 422 for each; never "all"; one status and one date only [v1.1 | 2026-10-31] |
| TC-B58 | acceptance | AC-18 | Orders 01/11, 02/11, 05/11, today 01/11; any, today, tomorrow, chosen 05/11; chosen date malformed, 1999, 2099 | Matches AC-18; malformed refused; far dates return empty, no 500 [v1.1 | 2026-10-31] |
| TC-B59 | acceptance | AC-19 | BT-AAAAAA, "Trần Thị Bé", +84 900 000 010; search `aaaaaa`, `BT-AAAAAA`, `tran thi`, `0900000010`, `+84 900 000 010`, `zzz` | First five find it; `zzz` empty [v1.1 | 2026-10-31] |
| TC-B60 | negative | AC-19 | Search `ab` and `09` | No search; 422 or message naming the 3-character rule; exactly 3 characters works [v1.1 | 2026-10-31] |
| TC-B61 | extra | AC-19 | Search `%`, `_`, `\`, `'; --`, NFC and NFD "Trần", upper case, 200 characters, control characters | Wildcards literal; no 500; accents and case ignored; NFC = NFD [v1.1 | 2026-10-31] |
| TC-B62 | extra | AC-19 | Search combined with status and date; search for an old Completed order (91 days) and for its phone | Combination is AND; old final orders are not found; no leak of their existence [v1.1 | 2026-10-31] |
| TC-B63 | acceptance | AC-20 | List shows 3; customer orders; pull-down request; then 503 and a timeout | New order appears; error envelope with `no-store`, no stale body presented as fresh [v1.1 | 2026-10-31] |
| TC-B64 | acceptance | AC-21 | Completed placed 89 and 91 days ago, Cancelled 91 days ago; list All, search by code, detail, as staff and owner | 89 days found; 91 days never in list or search; direct request 404 same as unknown code; owner too [v1.1 | 2026-10-31] |
| TC-B65 | edge | AC-21 | Placed 90 d minus 1 s, exactly 90 d, plus 1 s ago; clock +1 day on an 89-day order | Exactly 90 d still shown (timestamp rule); +1 s gone; one rule for list, search, detail, count [v1.1 | 2026-10-31] |
| TC-B66 | acceptance | AC-22 | New order placed 100 days ago for a date 75 days ago; default list; open; (run 1) confirm then complete; (run 2) cancel with a reason | In the default list marked "overdue 75 days"; opens; changes allowed; once Completed or Cancelled gone from list and detail for owner and staff [v1.1 | 2026-10-31] |
| TC-B67 | extra | AC-22 | Cancel the old order (past delivery date, no capacity row or a row with 0); cancel an old one for a date still loaded | No error from missing capacity row; capacity never negative; cakes returned once [v1.1 | 2026-10-31] |
| TC-B68 | extra | AC-22, FR-19 | Search by code of the old New order; retry of its completing request after the order left the window (lost reply) | Search outcome recorded (R-2: PRD silent). Retry: FR-19 says a repeat is not an error but api/06 answers 404 (R-1) [v1.1 | 2026-10-31] |
| TC-B69 | acceptance | AC-23 | 120 matching orders; fetch pages | 50, 50, 20; no duplicate, no gap; last page has no next marker [v1.1 | 2026-10-31] |
| TC-B70 | extra | AC-23 | Between page 1 and 2 a new order arrives and another changes status out of the filter | No duplicate, no crash; skipped row recorded (R-14) [v1.1 | 2026-10-31] |
| TC-B71 | negative | AC-23 | Page size 0, -1, 1000, text; forged, expired, other-user cursor | Validation error or clamp to 50; never unbounded; no 500 [v1.1 | 2026-10-31] |
| TC-B72 | extra | AC-22, AC-23 | 60 open orders older than 90 days plus 60 recent; page through the default list | Old overdue ones first (sort), no duplicate or gap across the window boundary; total 120 [v1.1 | 2026-10-31] |

## 4.8 Detail and status changes (FR-14 to FR-19, BR-2, BR-8)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B73 | acceptance | AC-24 | Order of 2 cakes confirmed by "Nhan Vien A", then cake price changed; open detail; a cancelled order | All FR-14 fields; stored prices; "last changed by Nhan Vien A, time"; cancelled order shows its reason; no history list in the response [v1.1 | 2026-10-31] |
| TC-B74 | negative | AC-24 | Detail of unknown code, malformed code, lower case code, SQL text | 404 or 400 without internals; same answer for unknown and for outside the window [v1.1 | 2026-10-31] |
| TC-B75 | acceptance | AC-26 | Staff A confirms a New order with a single request | Confirmed; one record (old, new, name, time); list shows the status; no confirmation token needed [v1.1 | 2026-10-31] |
| TC-B76 | acceptance | AC-27 | Complete a Confirmed order due in 5 days; complete a New order; complete a Completed order | First Completed; second refused, stays New; third is a repeat [v1.1 | 2026-10-31] |
| TC-B77 | acceptance | AC-28 | Limit 100, 98 accepted for 05/11, New order of 4; cancel with a reason; ask availability for 6 cakes; repeat with a Confirmed order | `cakes_accepted` 94; 6 fits; Confirmed order cancels the same way [v1.1 | 2026-10-31] |
| TC-B78 | negative | AC-28 | Cancel with no reason, empty, unknown, removed value `day_full`, other case, two reasons | 422 `CANCEL_REASON_REQUIRED`; order and capacity unchanged [v1.1 | 2026-10-31] |
| TC-B79 | acceptance | AC-28 | Read the allowed reasons; cancel a New and a Confirmed order with each of the four; send a reason with a non-cancel target | Exactly four values (customer asked, cannot deliver, cannot reach customer, fake or spam); stored and shown in detail; reason with Confirm refused [v1.1 | 2026-10-31] |
| TC-B80 | acceptance | AC-29 | Staff A and B hold the New order; A confirms; B cancels from the old view | B refused; order Confirmed; response carries the current status and a Vietnamese message [v1.1 | 2026-10-31] |
| TC-B81 | acceptance | AC-29 | Confirm twice; cancel twice with different reasons; complete twice | Both calls succeed; one record each; cakes returned once; first cancel reason kept [v1.1 | 2026-10-31] |
| TC-B82 | negative | AC-29 | All 16 status pairs with a fresh view; also by direct SQL | Only 4 allowed pairs succeed; Completed and Cancelled never change to another status; trigger refuses SQL [v1.1 | 2026-10-31] |
| TC-B83 | extra | AC-29 | Parallel: A confirms while B cancels the same New order | Exactly one wins; one record; capacity released only if cancel won [v1.1 | 2026-10-31] |
| TC-B84 | extra | AC-28 | Parallel: two cancels of one order; cancel while a customer orders the freed cakes at the capacity edge | Capacity released once, never negative; totals never above the limit [v1.1 | 2026-10-31] |

## 4.9 Record (BR-3)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B85 | acceptance | AC-47 | Customer creates, A confirms, owner completes; another cancelled with a reason; owner changes a price 120 000 to 130 000 | Records: "customer", old/new status, name, time, reason; settings record holds owner name, field, old, new, time [v1.1 | 2026-10-31] |
| TC-B86 | negative | AC-47 | Update or delete a record by API and by direct SQL | No endpoint; database refuses [v1.1 | 2026-10-31] |
| TC-B87 | extra | AC-47 | Switch off staff A; read a record and the detail line | Name stays; no history screen or history endpoint exists (deferred): request to the old path answers 404 [v1.1 | 2026-10-31] |

## 4.10 Notifications and privacy (FR-25, FR-26, BR-7)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B88 | acceptance | AC-42 | 3 phones: two with push permission, one without a token; a customer order is stored | Fake provider gets exactly 2 pushes within 60 s (server time); third sees the order after refresh [v1.1 | 2026-10-31] |
| TC-B89 | acceptance | AC-43 | Order with name "Tran Thi B", +84 900 000 010, address, note | Payload has code, cake count, delivery date, order id only; none of name, phone, address, note anywhere in it [v1.1 | 2026-10-31] |
| TC-B90 | acceptance | AC-43 | Open the order named in the payload with a valid session; with an expired session | Detail opens; after sign-in the same order opens; an order outside the window is not found [v1.1 | 2026-10-31] |
| TC-B91 | acceptance | AC-44 | Sign out; sign out all others; switch off; then store an order | No push to those phones; no token left; list request without session returns nothing [v1.1 | 2026-10-31] |
| TC-B92 | extra | AC-44 | Staff A signs out on a phone, staff B signs in on it with the same token; token registered twice | Token moves to B; A gets nothing; one push per order [v1.1 | 2026-10-31] |
| TC-B93 | extra | AC-42 | Provider returns invalid token, timeout, 500 | Invalid token removed; order placement still 201 and not slowed; no duplicate on retry [v1.1 | 2026-10-31] |
| TC-B94 | extra | AC-42 | Order insert rolls back (validation, capacity) | No push; push only after commit [v1.1 | 2026-10-31] |
| TC-B95 | extra | FR-25 | A New order stays unconfirmed 1 h, 1 day and 3 days (clock); an order due today and overdue | No reminder push of any kind (Q-11); only the new-order push exists [v1.1 | 2026-10-31] |
| TC-B96 | acceptance | AC-45 | Run the suite with log capture; grep logs, error bodies, push payloads for the fake names, phones, addresses, notes, codes, credentials | None found [v1.1 | 2026-10-31] |
| TC-B97 | extra | AC-45 | Scan app dependency lists (Gradle, SwiftPM) for analytics or crash-reporting SDKs | None; the admin app has no analytics (BR-7) [v1.1 | 2026-10-31] |

## 4.11 Effect on the Place Order limit (FR-27, BR-8)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B98 | acceptance | AC-46 | +84 900 000 010 places 5 orders in 24 h; one cancelled "customer asked"; place a 6th | Accepted [v1.1 | 2026-10-31] |
| TC-B99 | acceptance | AC-46 | Same with "cannot deliver", then with "cannot reach customer" | Accepted both times [v1.1 | 2026-10-31] |
| TC-B100 | acceptance | AC-46 | Same cancelled with "fake or spam" | 6th refused (429 `RATE_LIMITED`) within 24 h; accepted after the 24 h window [v1.1 | 2026-10-31] |
| TC-B101 | acceptance | AC-46 | 5 orders: 2 "cannot deliver", 1 spam, 2 open | 2 more accepted, 3rd refused [v1.1 | 2026-10-31] |
| TC-B102 | edge | AC-46 | Orders at 23 h 59 min and 24 h 01 min ago; phone as `0900000010` and `+84900000010` | Window and normalisation as for Place Order; cancelled handled the same [v1.1 | 2026-10-31] |
| TC-B103 | extra | AC-46 | Cancel as spam after the customer hit the limit; second cancel as spam of an order cancelled for another reason | Count changes at once; first reason kept so the second order is not counted [v1.1 | 2026-10-31] |
| TC-B104 | extra | FR-27 | Per-IP limit (10 an hour) after cancels; replayed Idempotency-Key | Per-IP limit and replay unchanged. `auth.md` and place-order docs must state the new rule (R-10) [v1.1 | 2026-10-31] |
| TC-B105 | extra | NFR | 9 000 orders (100 a day x 90) plus 200 open old ones; first list page, search by phone, status change | First page under 3 s; status change under 5 s (indicative) [v1.1 | 2026-10-31] |
| TC-B106 | extra | NFR | List of 50 rows: response size, EXPLAIN | Default list (any age, New/Confirmed) uses an index; no full scan at 9 000 rows [v1.1 | 2026-10-31] |
