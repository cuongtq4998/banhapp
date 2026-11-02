# Admin Orders Test Plan: Order Process Matrices and Roles (part 13)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.1). Holds: section 4.19 (new in v2.1 [v2.1 | 2026-11-02]), tests for PRD v1.10 (Approved 2026-11-02): BR-2, BR-8, FR-16 to FR-19, FR-28, FR-29, AC-26 to AC-29. Early mode: all results `Not run`. Cases TC-B201 to TC-B268.

Level key (every part from 13 on): **API** = contract test over HTTP against the running API (black box, QA package, any store); **DB** = needs a real PostgreSQL (concurrency, constraints, direct SQL, migration); **iOS** and **Android** = UI test on that platform (client stub or test backend). A case marked "API, DB" runs the API test on PostgreSQL. Status names: Received (R), Processing (P), Delivery date scheduled (S), Delivery started (D), Finished (F), Cancelled (X). Actions: A1 start processing, A2 enter or move the expected date, A3 start delivery with fee 25 000, A4 finish, A5 cancel with reason "cannot deliver". Each request carries the current status as the client's view (ADR-0028, name per api docs). The error names below are placeholders until the api document lists them: "refused" = 409 (stale view or transition not allowed), body shows the current status, order and records unchanged.

## 4.19.1 Transition matrix (BR-2, FR-19): every status x every action

Cell = result when the action is sent to an order in that status from a fresh view. OK(x) = allowed, new status x, one record. Repeat = same result, no second record. [v2.1 | 2026-11-02]

| From \ Action | A1 start processing | A2 expected date | A3 start delivery | A4 finish | A5 cancel |
| ------------- | ------------------- | ---------------- | ----------------- | --------- | --------- |
| R | OK(P) | refused | refused | refused | OK(X) |
| P | Repeat | OK(S) | refused | refused | OK(X) |
| S | refused | OK stays S (same date: Repeat) | OK(D) | refused | refused |
| D | refused | refused | Repeat (same fee) | OK(F) | refused |
| F | refused | refused | refused | Repeat | refused |
| X | refused | refused | refused | refused | Repeat (first reason kept) |

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B201 | acceptance | API | BR-2, AC-26, AC-27, AC-28, AC-49, AC-50 | Parameterised: 30 cells of the matrix, one request each on a fresh order in the starting status (valid date, fee 25 000, reason) | Each cell as in the matrix; for every refusal the order, the records and the day amounts are unchanged and the body shows the current status in Vietnamese |
| TC-B202 | acceptance | API | AC-26 | R to P with one request, no confirmation field | P; one record with old and new status, account name, time |
| TC-B203 | acceptance | API | AC-27, FR-17 | D to F with one request; F from R, P, S direct | F only from D; the other three refused with the current status |
| TC-B204 | negative | API | BR-2, FR-19 | Set status by name to the old values `confirmed`, `completed`, `new`, or an unknown name, `scheduled` | 400 or 409, nothing changes; the old names are not accepted as input |
| TC-B205 | negative | API | BR-2 | Skips: R to D, R to S, R to F, P to D, P to F, S to F with all required fields supplied | All refused; order unchanged |
| TC-B206 | negative | API | BR-2 | Backward moves: P to R, S to P, D to S, F to D, X to R, F to X | All refused |
| TC-B207 | extra | DB | BR-2 | Direct SQL update of status to a pair outside the matrix (and F to any, X to any) | The database refuses (constraint or trigger) or the case records "no DB guard" for atlas; application tests still pass |
| TC-B208 | acceptance | API, DB | AC-29 | Two staff hold one R order; A starts processing, B cancels from the old view | B refused, sees P; one record |
| TC-B209 | acceptance | API | AC-29 | A1 sent twice (double tap, retry) | Both answer P; one record |
| TC-B210 | extra | DB | AC-29 | Parallel: A1 and A5 sent at the same moment on one R order, 20 repeats | Exactly one wins each run; if A5 wins, X with cakes returned once; if A1 wins, A5 refused; never two records of different kind |
| TC-B211 | extra | DB | FR-19 | Parallel: A3 (fee 20 000) by two devices at once on one S order | One record; D; fee 20 000 stored once |
| TC-B212 | extra | DB | FR-19 | Parallel: A4 by two devices on one D order | One F, one record, second answers F as a repeat |
| TC-B213 | extra | API | FR-19 | A request with a stale view on an order that moved two steps (R view, order is D) with A4 | Refused, current status D shown |
| TC-B214 | extra | API | FR-19 | A request with no view or an unknown view value | 400 and unchanged, or treated as the current status per api doc (record which; question Q-P4) |
| TC-B215 | extra | API | AC-26 | The status-change record list of an order walked R to P to S to D to F | Five records in order, each with old and new status, account name, time; times not decreasing |

## 4.19.2 Cancel by step matrix (FR-18, BR-2, BR-8)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B221 | acceptance | API | AC-28, FR-18 | Cancel with each of the four reasons from R (4 orders) | X; reason stored; cakes returned to the requested date once each |
| TC-B222 | acceptance | API | AC-28 | Same four reasons from P (4 orders) | Same as TC-B221 |
| TC-B223 | acceptance | API | AC-28, BR-2 | Cancel with a valid reason from S, from D, from F | Refused each time; status, expected date, fee, capacity unchanged |
| TC-B224 | acceptance | API, DB | AC-28 | Limit 100, 98 accepted for 05/11 incl. an R order of 4; cancel with reason; ask availability for 6 cakes on 05/11 | X; the date is available |
| TC-B225 | acceptance | API, DB | AC-28 | Same as TC-B224 with a P order of 4 | Same |
| TC-B226 | negative | API | AC-28, BR-8 | Cancel from R with no reason, empty, unknown, the removed `day_full`, other case, two reasons, reason as number | Refused naming the field; still R |
| TC-B227 | negative | API | AC-28, BR-8 | Cancel from S, D, F with no reason or a bad reason | Refused; error is the step refusal or the field error, either way unchanged (record which wins) |
| TC-B228 | acceptance | API | AC-29 | Second cancel of an X order with another reason | Succeeds as a repeat; first reason kept; no second record; cakes returned once |
| TC-B229 | extra | API | AC-28, BR-15 | Order had an expected date (S) and then cannot be cancelled; check a P order that never had a date | Cancel from S refused; cancel from P works; no stored expected date on an X order |
| TC-B230 | extra | API, DB | BR-8, FR-27 | Cancel with `fake_spam` and with another reason from R and P; count toward the phone limit of 5 | Only `fake_spam` still counts; others free a slot |
| TC-B231 | extra | API | FR-18 | Cancel request on an order of a purged age (older than 90 days, F or X) | Not found; nothing changes |
| TC-B232 | extra | DB | AC-28 | Cancel R order while a customer orders the freed cakes at the limit, 20 repeats | Remaining amount never negative and never above the limit; no double return |
| TC-B233 | extra | DB | AC-28, BR-15 | Orders on date 12/11 (limit 10): R of 4, S of 4 requested for 12/11 expected 15/11; cancel the R only | Remaining on 12/11 rises by 4 only; the S order still holds 4 on 12/11 |

## 4.19.3 Role matrix (staff, owner, customer; AC-8 style)

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-B241 | acceptance | API | FR-16 to FR-18, FR-28, FR-29 | Staff session performs A1 to A5 on suitable orders | All work; records show the staff name |
| TC-B242 | acceptance | API | same | Owner session performs A1 to A5 | All work; records show the owner name |
| TC-B243 | negative | API | AC-8 | Customer (public order API, no admin session) calls every admin action: A1 to A5, set date, set fee | 401 or 403; nothing changes; no hint of the order |
| TC-B244 | negative | API | AC-8, AC-10 | Deactivated staff and expired session call A1 to A5 | 401; unchanged |
| TC-B245 | negative | API | AC-8 | Staff calls Delivery estimate settings (FR-23) | 403 (owner only unchanged) |
| TC-B246 | acceptance | API | FR-23 | Owner edits district estimate; staff reads the district list | Owner saves; staff cannot save |
| TC-B247 | extra | API | AC-8 | Customer reads the order he placed (public confirmation, if any) | Shows no real fee and no expected date unless the api document says so (question Q-P5) |
| TC-B248 | extra | API | FR-14 | Staff and owner read the same order at each step | Same fields for both; real fee and expected date only once set |
| TC-B249 | extra | API | AC-8 | A role change (staff switched off) between two steps of one order | The next step by that account is refused; earlier records keep the name |
| TC-C201 | acceptance | iOS, Android | AC-26 to AC-29 | Detail shows only the actions valid for the status: R (Start processing, Cancel), P (Set expected date, Cancel), S (Change date, Start delivery), D (Finish), F and X (none) | Exactly those; no Cancel from S on; no Finish before D |
| TC-C202 | acceptance | iOS, Android | AC-27 | Finish asks one confirmation naming the order code; accept and decline | Accept: F; decline: unchanged |
| TC-C203 | acceptance | iOS, Android | AC-28 | Cancel asks four reasons and a confirmation; Cancel disabled until a reason; back leaves status | As written |
| TC-C204 | acceptance | iOS, Android | AC-29 | Stub returns refusal (stale view) on each action | Current status shown in Vietnamese, buttons refreshed |
| TC-C205 | extra | iOS, Android | FR-19 | Double tap on Start processing, Set date, Start delivery, Finish; slow response | One request each; button disabled while sending |
| TC-C206 | extra | iOS, Android | AC-8 | Staff and owner sign in on the same order | Same actions; no owner-only action on the detail |
| TC-C207 | extra | iOS, Android | BR-2 | Step indicator at each of the six statuses and at X | Six steps; current step marked; X shown apart (copy per design) |
