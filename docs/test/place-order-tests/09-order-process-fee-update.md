# Place Order: Tests for the Fee and Process Change (part 09)

Part of [place-order-tests.md](../place-order-tests.md) (v1.8). Holds: section 4.8 (new in v1.8 [v1.8 | 2026-11-02]), tests for PO BR-3, BR-5, BR-9, FR-9, AC-11, AC-14, AC-28 after PRD place-order v1.7 (owner decision 2026-11-02). Early mode: all `Not run`. Level key: **API** = contract test over HTTP; **DB** = needs PostgreSQL; **iOS** and **Android** = UI test per platform. Cases TC-P101 to TC-P125. Admin-side tests are in the admin plan parts 13 to 16.

| ID | Kind | Level | Source | Case | Expected |
| -- | ---- | ----- | ------ | ---- | -------- |
| TC-P101 | acceptance | API | AC-11, BR-3 | Read the district list | Each district has an estimated fee marked as an estimate (field name per api); a district not on the list is refused on order |
| TC-P102 | acceptance | iOS, Android | AC-11 | Address step: choose each district | Estimate shown with the text that the final fee is told at delivery; the word "fee" never appears as a charge |
| TC-P103 | negative | iOS, Android | AC-11 | District off in settings while the address step is open | Not selectable on refresh; selected one refused with a message |
| TC-P104 | acceptance | iOS, Android | AC-14, FR-9 | 2 of cake A at a, 1 of B at b, estimate f; open the review | Cake amount 2a + b; f labelled estimate; no figure equals 2a + b + f |
| TC-P105 | extra | iOS, Android | AC-14 | Review with estimate 0 is impossible (min 1); with estimate 10 000 000 and cakes 50 000 | Amount 50 000 only; estimate shown fully, no overflow of the layout |
| TC-P106 | acceptance | API | BR-5, AC-14 | Place an order: the request no longer sends a total with fee; response and stored order | Stored cake amount = sum of price x quantity; no real fee stored; no total with fee |
| TC-P107 | negative | API | BR-5 | Old client sends `expected_total_vnd` equal to cakes + estimate | Refused as a mismatch or the field ignored per api doc; never a stored total with fee (question Q-P9) |
| TC-P108 | negative | API | BR-5 | Old client sends `expected_total_vnd` equal to cakes only | Accepted |
| TC-P109 | negative | API | BR-5 | Total mismatch: cakes - 1, cakes + 1, 0, negative, string | Refused as before (price changed or invalid); no order stored |
| TC-P110 | acceptance | API | BR-5 | Price changed between review and send | Refused with the new price as before; order not stored |
| TC-P111 | extra | API | BR-3 | Estimate changed by the owner between review and send | Order accepted (estimate is information only); stored order has no fee |
| TC-P112 | extra | API | BR-3 | District switched off between review and send | Refused with the district message |
| TC-P113 | extra | API | BR-5 | Order of 20 cakes at 100 000 000 | Cake amount exact (2 000 000 000), no overflow |
| TC-P114 | acceptance | API, DB | AC-28, BR-9 | Date at the limit; cancel the order in the database (no screen in this slice); read availability | Remaining rises by the order's cakes; date selectable again |
| TC-P115 | acceptance | API, DB | AC-28, BR-9 | Date at the limit; set an expected delivery date on that order in the database (or by the admin API) to another day | Remaining amounts of both days unchanged |
| TC-P116 | extra | API, DB | BR-9 | Order of a customer on 10/11 expected 15/11; customers ask for 10/11 and 15/11 availability | 10/11 shows the order's cakes held; 15/11 shows none held |
| TC-P117 | extra | API, DB | BR-9 | Cancel an order that has an expected date (only possible before Delivery date scheduled, so none yet) | Not applicable; the admin refusal TC-B223 covers it |
| TC-P118 | extra | DB | BR-9 | Concurrent: two customers order the last 2 cakes of a date while staff move expected dates | Exactly one succeeds; amounts never negative |
| TC-P119 | acceptance | DB | BR-5 | Old orders (migration, admin TC-B431) in the place-order read paths | Still readable; amounts unchanged |
| TC-P120 | acceptance | iOS, Android | FR-9 | Confirmation screen after ordering | Shows cake amount, estimate with the "told at delivery" text, and that the customer pays the cakes plus the real fee at handover (wording per design) |
| TC-P121 | extra | iOS, Android | FR-9 | VoiceOver and TalkBack on review and confirmation | Estimate read as "estimated" |
| TC-P122 | extra | iOS, Android | AC-14 | Dynamic Type largest on review | Lines do not truncate the word "estimate" |
| TC-P123 | extra | iOS, Android | AC-11 | Switch district twice quickly | The estimate shown matches the last district |
| TC-P124 | extra | iOS, Android | AC-14 | Review in Vietnamese only (no English copy leaks) | No untranslated string |
| TC-P125 | extra | API | AC-11 | District name unchanged after estimate change; order keeps district name | Order shows the district name only (no stored fee) |

Questions: Q-P9 (to atlas): is `expected_total_vnd` kept (cakes only) or removed from the order request; what does an old client get? Ids: PO BR-3 TC-P101, TC-P111; BR-5 TC-P106 to TC-P113; BR-9 TC-P114 to TC-P118; FR-9 TC-P104, TC-P120; AC-11 TC-P101 to TC-P103; AC-14 TC-P104, TC-P105, TC-P107 to TC-P109; AC-28 TC-P114, TC-P115. PO AC-35 and AC-36 are named in the admin PRD impact list but not changed; cases unchanged, to be rechecked in execute mode. [v1.8 | 2026-11-02]
