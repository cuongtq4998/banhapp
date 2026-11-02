# Admin Orders Test Plan: Real Fee, Expected Date, Capacity (part 14)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.1). Holds: sections 4.20 to 4.22 (new in v2.1 [v2.1 | 2026-11-02]), tests for FR-28, FR-29, BR-11, BR-15, BR-3, AC-49, AC-50, AC-51. Level key: see [part 13](13-order-process-matrices.md). Cases TC-B301 to TC-B365, TC-C301 to TC-C314. Early mode: `Not run`. Shop today is Vietnam time; tests use the controlled clock (E-1). Seed: limit 10 for capacity tests, order R1 of 2 cakes at 120 000, requested date 10/11, today 02/11.

## 4.20 Real delivery fee (FR-29, BR-11, AC-50, AC-51)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B301 | acceptance | API | AC-50 | Start delivery on an S order with no fee field | Refused, field named; stays S; no record |
| TC-B302 | acceptance | API | AC-50, BR-11 | Fee 0 | D; detail shows free delivery; fee 0 stored (not "missing") |
| TC-B303 | acceptance | API | AC-50 | Fee 25 000 | D; detail shows 25 000; record holds old and new status and the fee |
| TC-B304 | boundary | API | BR-11 | Fees 1, 9 999 999, 10 000 000 (three orders) | All accepted |
| TC-B305 | negative | API | AC-50, BR-11 | Fee -1 | Refused naming the field; stays S |
| TC-B306 | negative | API | AC-50, BR-11 | Fee 10 000 001 | Refused |
| TC-B307 | negative | API | AC-50 | Non-integer: `20000.5`, `"25000"` (string), `1e4`, `"abc"`, `true`, `[]`, `{}` | Each refused; stays S |
| TC-B308 | negative | API | AC-50 | Fee null, empty string, whitespace, missing key | Refused as "no fee"; null is not 0 |
| TC-B309 | negative | API | BR-11 | Fee `9223372036854775808`, `-0`, `00025000`, `25 000` with space, `25,000` | Refused or (for `-0` and leading zeros per JSON) refused as invalid JSON number; no 500 |
| TC-B310 | negative | API | AC-50 | Fee sent with A1, A2, A4, A5 (any step except A3) on R, P, S, D | The fee is refused or ignored without storing; order has no fee until A3 (record which: question Q-P2) |
| TC-B311 | negative | API | AC-50 | Fee sent to R, P, F, X orders by a direct fee request or A3 | Refused; no fee stored |
| TC-B312 | acceptance | API | FR-19 | A3 twice with the same fee 25 000 | Second is a repeat: D, one record, fee unchanged |
| TC-B313 | negative | API | FR-19, AC-50 | A3 on a D order with a different fee (25 000 then 30 000) | Refused (no fee at any other step); stored fee 25 000; one record (question Q-P2) |
| TC-B314 | extra | API | BR-11 | Fee entered when a form of A3 also carries an unknown field | Unknown field ignored or 400; never stored |
| TC-B315 | extra | API | BR-11 | Fee entered while the district estimate is 30 000 and later changed | Order keeps the real fee; estimate change never touches it |
| TC-B316 | extra | API | AC-50 | A3 on S order whose district was switched off or deleted since ordering | Works; fee stored; district name still shown |
| TC-B317 | extra | API | AC-50 | Fee needed from a fresh view only: A3 with a stale view (order already D) | Refused or repeat, never a second fee |
| TC-B318 | acceptance | API | AC-51 | Detail of R1 before the fee, at R, P, S | Cake total 240 000, fee "told at delivery" (null plus flag), no total with fee, no amount to collect |
| TC-B319 | acceptance | API | AC-51 | R1 after fee 20 000 | 240 000, 20 000, amount to collect 260 000 |
| TC-B320 | acceptance | API | AC-51 | R1 after fee 0 | 240 000, free delivery, amount to collect 240 000 |
| TC-B321 | extra | API | AC-41 | R1 with fee 20 000; then price 130 000 and district estimate 25 000 | Order still 120 000 per cake, 20 000, 260 000 |
| TC-B322 | extra | API | AC-41 | R1 without fee; price changes to 130 000 | Order still 240 000 and no fee |
| TC-B323 | extra | API | AC-51 | Fee value 10 000 000 with cakes 100 000 000 x 20 | Amounts exact in whole dong; no overflow, no rounding |
| TC-B324 | extra | DB | AC-50 | Fee column holds 0 and NULL differently; direct SQL negative fee | NULL means not entered; DB refuses negative or the gap is reported |
| TC-B325 | extra | API | FR-14 | List row for an order with fee entered | Row shows the cake total only (not total with fee), per FR-9 |

## 4.21 Expected delivery date (FR-28, BR-15, BR-3, AC-49)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B331 | acceptance | API | AC-49 | P order requested 10/11, A2 with 12/11 | S; detail shows 12/11 and requested 10/11; record: name, time, no old date, new 12/11 |
| TC-B332 | acceptance | API | AC-49 | Then 13/11, then 12/11 again | Two more records with old and new date; stays S |
| TC-B333 | acceptance | API | AC-49 | Date before today (01/11), `2026-11-01T00:00`, date none | Refused; nothing stored; still P |
| TC-B334 | boundary | API | BR-15 | Date = today (02/11) | Accepted (not before today) |
| TC-B335 | boundary | API | BR-15 | Clock at 23:59 and 00:01 Vietnam time with date = that day, and clock set to UTC day behind | Shop calendar used; "today" is Vietnam date |
| TC-B336 | boundary | API | BR-15 | Date before the requested date (08/11 for 10/11) and on it | Accepted (information only) |
| TC-B337 | negative | API | BR-15 | Invalid dates: 31/02, 2026-13-01, `2026-11-5`, `05/11/2026` string, number, text, empty | Refused naming the field |
| TC-B338 | boundary | API | BR-15 | Far dates: today + 1 year, 9999-12-31, year 0001 | Behaviour recorded; no 500 (question Q-P3: upper bound not defined) |
| TC-B339 | acceptance | API | BR-15 | Date moved 25 times in a row | All accepted; 25 records plus one for entry; no limit of "1 to 2 days" |
| TC-B340 | extra | API | BR-15 | Date moved by 10 days from the previous | Accepted; "about 1 to 2 days" is not enforced |
| TC-B341 | acceptance | API | AC-49, FR-19 | Same expected date sent twice | One record |
| TC-B342 | negative | API | FR-28 | A2 on R, D, F, X orders | Refused; no date stored |
| TC-B343 | negative | API | FR-28 | A2 on a P order is the first entry and moves it to S; second device sends A2 from the old P view with another date | Second is accepted as a move if the api treats the view P as stale-but-compatible, else refused with current S; record which (question Q-P1) |
| TC-B344 | extra | DB | FR-28 | Two devices move the date at once (13/11 and 14/11) from S | Both accepted in some order or one refused as stale; records form a chain: each old date equals the previous new date |
| TC-B345 | extra | DB | FR-28 | Two devices enter the first date at once (P, 12/11 and 13/11) | One first entry (no old date); the other is a move or refused; never two first entries |
| TC-B346 | extra | DB | FR-28 | Move date racing A3 (start delivery) | Either D with the old date, or the new date then D; no move recorded after D |
| TC-B347 | acceptance | API | BR-3, AC-49 | Read the record list after three moves | Each row: account name, time, old date or none, new date; newest order as api doc; times correct to the clock |
| TC-B348 | extra | API | BR-3 | Records of a date move made by staff and then by owner | Names differ per record; account rename keeps old name or shows current per auth rule (record) |
| TC-B349 | extra | API | BR-15 | Date entered, order later D and F | Expected date stays in the detail and is not editable |
| TC-B350 | extra | API | BR-15 | The customer is not messaged on a move: check push recording and mail outbox | No push, no mail (Q-35 assumption) |
| TC-B351 | extra | API | FR-14 | Expected date with Vietnam time near midnight, read by a client in another zone | A date only, no time zone shift (value is a calendar date) |

## 4.22 Capacity does not move (BR-15, AC-49, PO BR-9)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B361 | acceptance | API, DB | AC-49, BR-15 | Limit 10; R1 of 2 cakes for 10/11; remaining for 10/11 and 12/11 read; A2 with 12/11; read both again | Both remaining amounts identical before and after |
| TC-B362 | acceptance | API, DB | BR-15 | Date moved 5 times across five days, one a full day | No remaining amount changes; the move to a full day is accepted |
| TC-B363 | extra | API, DB | BR-15 | A day at limit; staff set the expected date of a P order onto that day | Accepted; the customers still cannot order more on that day |
| TC-B364 | extra | API, DB | BR-15 | Expected date outside the notice days, on a day with no slot, on a closed day | Accepted (not checked against lead days or slots) |
| TC-B365 | extra | API, DB | BR-15, AC-28 | A3, A4 after a moved date; read remaining | Unchanged by D and F too; the requested date still holds the cakes after F |
| TC-C301 | acceptance | iOS, Android | AC-49 | Date picker offers today and later; earlier days disabled; confirm | Date saved; detail shows expected and requested dates |
| TC-C302 | acceptance | iOS, Android | AC-49 | Move the date three times | Records list shows old and new date each time |
| TC-C303 | negative | iOS, Android | AC-49 | Stub refuses a past date (picker bypassed) | Error naming the date; status unchanged |
| TC-C304 | acceptance | iOS, Android | AC-50 | Start delivery with the fee field empty | Button disabled or error naming the fee; no request, or request refused and error shown |
| TC-C305 | acceptance | iOS, Android | AC-50 | Fee 0 | Detail shows free delivery text |
| TC-C306 | acceptance | iOS, Android | AC-50 | Fee 25 000 | Detail shows 25 000 |
| TC-C307 | negative | iOS, Android | AC-50 | Type `-1`, `10000001`, `12.5`, `1e3`, letters, paste with spaces and dots | Refused with a field message; no request for clearly invalid input |
| TC-C308 | extra | iOS, Android | AC-50 | Fee field keyboard: numeric pad, grouping of thousands as typed, VND suffix | Value sent as whole number; display grouped per design |
| TC-C309 | acceptance | iOS, Android | AC-51 | Detail before and after the fee | "Told at delivery" then fee and amount to collect 260 000 |
| TC-C310 | extra | iOS, Android | FR-28 | Fee and date forms at Dynamic Type largest and TalkBack or VoiceOver | Labels read; fields reachable; actions not clipped |
| TC-C311 | extra | iOS, Android | FR-19 | Network lost while sending the fee; retry | One record after retry; fee not twice |
| TC-C312 | extra | iOS, Android | FR-28 | Device date and time zone set to another country | "Not before today" uses the shop's today (server date), not the device |
| TC-C313 | acceptance | iOS, Android | BR-15 | Detail shows the requested date and the expected date as two labelled lines | Both; the expected date row absent until set |
| TC-C314 | extra | iOS, Android | FR-19 | Orientation change and background during the date form | Entered value kept; no duplicate request |
