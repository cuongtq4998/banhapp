# Admin Orders Test Plan: Date Range and Fee Correction (part 17)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.2). Holds sections 4.29 and 4.30 (new in v2.2 [v2.2 | 2026-11-02]) for FR-28, FR-30, BR-15, BR-17, AC-49, AC-53 (PRD v1.12), api/09 v1.1, ADR-0033 v1.2, data-model/06 v1.2. Early mode: all `Not run`. Fake data only. Levels: API contract (shape, codes, fixtures), API+DB (real PostgreSQL), UI iOS and Android (clients). S = Delivery date scheduled, D = Delivery started. Let T = shop today on the Vietnam calendar (UTC+7, no daylight saving).

## 4.29 Expected date range (FR-28, BR-15, AC-49, api/09 10.13.1 and 10.13.2)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B501 | boundary | API+DB | AC-49, FR-28 | Processing order, `to_status` S with date T - 1 | 422 `VALIDATION_FAILED`, field `EXPECTED_DATE_PAST`; stays Processing; no `order_expected_date_change` row; no event |
| TC-B502 | boundary | API+DB | AC-49 | Date T | 200, S, date T stored, one change row |
| TC-B503 | boundary | API+DB | AC-49 | Date T + 7 | 200, accepted (inclusive) |
| TC-B504 | boundary | API+DB | AC-49 | Date T + 8 | 422 `EXPECTED_DATE_TOO_FAR`; stays Processing; no row |
| TC-B505 | boundary | API+DB | AC-49 | Dates T - 365 and T + 3650 | `EXPECTED_DATE_PAST` and `EXPECTED_DATE_TOO_FAR` (never accepted) |
| TC-B506 | negative | API | FR-28 | Date "2026-02-30", "2026-13-01", "12/11/2026", "", number, null, array | 422 `EXPECTED_DATE_INVALID` (not a date); missing field gives `EXPECTED_DATE_REQUIRED` |
| TC-B507 | boundary | API+DB | BR-15 | Clock at 2026-11-02 16:59:59Z (23:59:59 Vietnam) and 17:00:00Z (00:00:00 next day), T fixed per clock | Before: T = 02/11, date 02/11 accepted, 01/11 past. At 17:00:00Z: T = 03/11, date 02/11 refused `EXPECTED_DATE_PAST`, 10/11 accepted, 11/11 `TOO_FAR` |
| TC-B508 | boundary | API+DB | BR-15 | UTC date differs from Vietnam date (clock 2026-11-02 18:00Z = 03/11 01:00) | The Vietnam date rules, not UTC: 02/11 refused, 03/11 accepted |
| TC-B509 | boundary | API+DB | BR-15 | Month and year ends: T = 2026-12-28 to 2027-01-01 (T + 7 crosses the year) | T + 7 accepted, T + 8 refused across the year end; no off-by-one on 31-day month |
| TC-B510 | extra | API+DB | ADR-0033 D10 | Valid request accepted at 16:59Z with date T; the same request replayed (same key) at 17:01Z when the date would now be past | 200 `Idempotent-Replay: true`, stored result returned; no new row; no `EXPECTED_DATE_PAST` |
| TC-B511 | extra | API+DB | ADR-0033 D10 | Same replay with a changed body (date T + 8 instead of T) | Not a replay; validated on its own: `EXPECTED_DATE_TOO_FAR` (or key-reuse error per api/04) |
| TC-B512 | acceptance | API+DB | FR-28, AC-49 | PUT expected-delivery-date on an S order: same four boundaries (T - 1, T, T + 7, T + 8) | Same codes as TC-B501 to TC-B504; stored value unchanged on refusal; change row only on success |
| TC-B513 | acceptance | API+DB | FR-28 | Move the date 5 times, including back to an earlier valid date | Every move accepted; 5 change rows in order with old, new, account name, time; no limit on moves |
| TC-B514 | negative | API | FR-28 | PUT with `previous_expected_delivery_date` stale (another device moved it) | 409 `ORDER_STATE_CHANGED`, `details.order` current; no overwrite |
| TC-B515 | extra | API+DB | FR-28 | Order with an S date that is now in the past (days later); move it to T or to a later date; or press Start delivery | Move validated against the new today; Start delivery does not check the stored date; unrelated to the range |
| TC-B516 | extra | API | api/09 10.13.1 | Date sent with `to_status` Processing, Finished, DeliveryStarted, Cancelled | 422 `FIELD_NOT_ALLOWED` for each; no write |
| TC-B517 | extra | API contract | api/09 10.13.4 | Fixtures `error-validation-expected-date-past.json`, `-too-far.json` decode with the contracts package and match the live body | Codes, field names and error shape identical |
| TC-C501 | acceptance | UI iOS, Android | AC-49 | Date picker for S: lowest selectable T, highest T + 7 | Days outside the range disabled or refused with the message for past or too far; no crash; same on both platforms |
| TC-C502 | extra | UI iOS, Android | AC-49 | Picker open past midnight Vietnam (clock control) then Save | Server answer `EXPECTED_DATE_PAST` shown as a field message; entered data kept; picker refreshes its bounds |
| TC-C503 | extra | UI iOS, Android | FR-28 | Device time zone not Vietnam (for example UTC-8) | Picker bounds follow the shop calendar from the server date (or are validated by server), not the device zone |

## 4.30 Real fee correction (FR-30, BR-17, AC-53, api/09 10.13.6, data-model/06)

Endpoint PUT `/v1/admin/orders/{code}/delivery-fee`, body `expected_status`, `previous_delivery_fee_vnd`, `delivery_fee_vnd`.

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B521 | acceptance | API+DB | AC-53, FR-30 | D order, fee 25 000, staff corrects to 30 000 | 200 detail: fee 30 000, amount to collect = cakes + 30 000; one `order_fee_correction` row |
| TC-B522 | acceptance | API+DB | BR-17, BR-3 | Row content after TC-B521 | `old_fee_vnd` 25 000, `new_fee_vnd` 30 000, `changed_by_name` = account name snapshot, `changed_by_account_id` set, `changed_at` near now; no other field |
| TC-B523 | acceptance | API+DB | FR-30 | Detail `fee_corrections[]` after two corrections (25 000 to 30 000 to 20 000) | Two entries oldest first: old, new, name, time; matches the DB rows; only latest in `delivery_fee_final_vnd` |
| TC-B524 | acceptance | API | FR-30 | Role owner and role staff both correct | 200 for both; names differ in the rows |
| TC-B525 | negative | API | api/05 | No token, expired token, revoked session | 401 each; no write, no row |
| TC-B526 | negative | API | api/05 | A customer-side or non-admin token, wrong-role value (removed staff account) | 401 or 403 per api/05; no write |
| TC-B527 | negative | API+DB | FR-30 | Status Received, Processing, S (fee not yet entered) | 422 `FEE_CORRECTION_NOT_ALLOWED` when `expected_status` is not D; 409 `ORDER_STATE_CHANGED` when the body says D but the order is not; stored fee null stays null |
| TC-B528 | negative | API+DB | BR-17 | Status Finished and status Cancelled | 409 `ORDER_STATE_CHANGED` with current detail; fee and rows unchanged |
| TC-B529 | negative | API | FR-30 | `expected_status` Finished, Cancelled, "Completed" (legacy), "" | 422 `FEE_CORRECTION_NOT_ALLOWED` or `VALIDATION_FAILED`; no write |
| TC-B530 | boundary | API+DB | BR-11 | New fee 0 (free) and 10 000 000, from a non-equal previous | Both 200; 0 stored as 0, amount to collect = cakes |
| TC-B531 | boundary | API | BR-11 | New fee -1, 10 000 001, 99999999999, 2^63 | 422 `FEE_INVALID`; no write |
| TC-B532 | negative | API | FR-30 | New fee 25000.5, "25000", "abc", true, null, 1e3 | 422 `FEE_INVALID`; absent gives `FEE_REQUIRED`; absent previous gives `PREVIOUS_FEE_REQUIRED`; previous negative or fractional `FEE_INVALID` |
| TC-B533 | negative | API+DB | api/09 | New fee equals stored and equals previous | 422 `FEE_UNCHANGED`; no row (CHECK `new <> old` never reached) |
| TC-B534 | negative | API+DB | api/09 | Previous equals new but stored differs (stale view) | 409 `ORDER_STATE_CHANGED` (compare key checked first per table); no overwrite |
| TC-B535 | acceptance | API+DB | api/09, ADR-0033 | `previous_delivery_fee_vnd` differs from stored | 409 `ORDER_STATE_CHANGED`, `details.order` holds current fee and `fee_corrections[]`; nothing changed |
| TC-B536 | acceptance | API+DB | ADR-0033 D10 | Replay the same request and key | 200 `Idempotent-Replay: true`, same body; exactly one row; fee not re-applied |
| TC-B537 | extra | API+DB | ADR-0033 D10 | Replay after a third device changed the fee again | Stored result of the first call returned (replay), no new write; the later value stays |
| TC-B538 | extra | API+DB | FR-30 | Two devices send 25 000 to 30 000 and 25 000 to 40 000 at once (parallel) | One 200, one 409; one row; final fee equals the winner; never both rows |
| TC-B539 | extra | API+DB | FR-30 | Same device double tap, no key, same body twice at once | One write; the second gets 409 or `FEE_UNCHANGED`; one row |
| TC-B540 | extra | API+DB | FR-30 | Correct while another device presses Finish at once | Either order ends consistent: Finish first gives 409 for the fee; fee first gives Finished with the corrected fee; never a fee change on Finished |
| TC-B541 | negative | DB | data-model/06 | Direct SQL: `UPDATE customer_order SET delivery_fee_final_vnd` on a Finished order (also Cancelled) | Exception from `customer_order_immutable`; value unchanged |
| TC-B542 | negative | DB | data-model/06 | Direct SQL: change `expected_delivery_date` on Finished and on Cancelled | Exception; value unchanged |
| TC-B543 | negative | DB | data-model/06 | Direct SQL: fee change on S or Received row; fee set to null on D; status change D to Finished together with a fee change | Refused each (only D to D with old not null, or S to D first entry); the combined statement refused |
| TC-B544 | extra | DB | data-model/06 | Direct SQL on `order_fee_correction`: UPDATE, DELETE, insert with `new = old`, fee 10 000 001, order missing | UPDATE and DELETE raise (insert-only trigger); CHECKs refuse the rest; FK RESTRICT |
| TC-B545 | extra | DB | data-model/06 | Remove an account that corrected a fee | `changed_by_account_id` null, `changed_by_name` kept; detail still shows the name |
| TC-B546 | extra | API | BR-17 | Correction does not touch estimate, stored total, `date_changes[]`, capacity, `order_event` types | All unchanged; no push, no customer message (BR-15) |
| TC-B547 | extra | API contract | api/09 10.13.6 | Fixtures `order-detail-fee-corrected.json` (two entries), `error-validation-fee-invalid.json`, `error-fee-correction-not-allowed.json`, `error-order-state-changed-fee.json` decode and match live bodies | Shapes identical; no field missing in either direction |
| TC-B548 | extra | API | api/05 | Rate limit and `no-store` on the PUT; order code unknown | 429 as api/05; `Cache-Control: no-store`; 404 `ORDER_NOT_FOUND` |
| TC-C521 | acceptance | UI iOS, Android | AC-53 | D order: open "Correct fee", enter 30 000, save | Detail shows 30 000 and new amount to collect; history list shows account, time, old, new |
| TC-C522 | acceptance | UI iOS, Android | BR-17 | Action present only at D; absent at Received, Processing, S, Finished, Cancelled | No correction control at other statuses |
| TC-C523 | negative | UI iOS, Android | BR-11 | Enter -1, 10 000 001, 12.5, empty, same value | Field message per code; Save blocked or server message shown; no change |
| TC-C524 | extra | UI iOS, Android | api/09 | Two devices: the second saves from the stale screen | Conflict message, screen reloads with current fee and history; entry not silently lost |
| TC-C525 | extra | UI iOS, Android | FR-30 | Staff role and owner role | Both can correct; unauthenticated session returns to sign-in |
