# Place Order Test Report: Open questions and change log

Part of the place-order test plan and report, v1.7 (index: [place-order-tests.md](../place-order-tests.md)). Sections in this part: 9. Open Questions / Change log (9.1 to 9.5) and the Change log table. Section numbers and ids are unchanged from v1.6.

| Ids in this part | Range |
| ---------------- | ----- |
| Test cases defined (table rows) | none |
| Test cases mentioned | TC-1 to TC-267 (64) |
| Slice 1 plan ids defined (TC-S1) | none |
| Defects mentioned | D-1 to D-20 (9) |

## 9. Open Questions / Change log

Review of the whole document set (PRD v1.2, UI v1.0, system docs v1.0, ADRs). Class is business or technical. `Blocking` means blocking for test design or for test execution. The questions are grouped by who should answer. None is blocking to approve the PRD.

### 9.1 Requirements questions (scribe-requirements and owner)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-S1 | PRD section 12 still lists Q-T1 to Q-T6 as "Open (architect)" while ADR-0008, 0009, 0011, 0013, 0014, 0015 answer them. Update the status and cross-reference. | Keeps the approved PRD consistent; test basis (phone format, order code, idempotency) comes from ADRs, not from the PRD. | No | technical | Open (scribe-requirements) | |
| Q-S2 | AC-12 says "not a valid number" and A-6 "Vietnamese format". ADR-0009 accepts only mobile numbers (landlines and foreign numbers rejected). Is that the intended business rule? A customer with only a landline cannot order. | AC-12 test data (TC-28, TC-29) and customer reach. | No | business | Open (owner via scribe-requirements) | |
| Q-S3 | BR-4 says "no maximum per order other than the remaining amount", but ADR-0009 caps one cake at 99 (and availability at 396). Accept the technical cap, or state it in the PRD? | A tester cannot fail or pass an order of 100 of one cake without knowing. | No | business | Open (scribe-requirements) | |
| Q-S4 | AC-23 "a confirmed order still shows the price at confirmation": no screen or endpoint shows a stored order (S-9 has no prices; no read endpoint). Is a database-level check (TC-45) acceptable evidence? | AC-23 is untestable through the product. | No | business | Open (scribe-requirements) | |
| Q-S5 | AC-28 says testable only once cancellation exists, but order-lifecycle.md creates the trigger now and says AC-28 is testable at database level. Which one counts for this slice? | Whether AC-28 can be Pass or only Blocked at verdict time. | No | business | Open (scribe-requirements) | |
| Q-S6 | AC-29 forbids a visible "sample" marker, but the sample values in api.md use the word "mẫu" (sample): "Tiệm Bánh Mẫu", "Quận Mẫu 1", "Mô tả mẫu", "Đường Mẫu". These would appear in the app and look like a marker. Which sample wording is allowed? Define what counts as a "visible sample marker". | AC-29 pass/fail (TC-66, TC-131). | No | business | Open (scribe-requirements; seed text by forge-dev) | |
| Q-S7 | G-3 says every customer can quote the code, but after the app is closed the code is lost (no order lookup, no list, no history, S-9 not restorable). Is that acceptable for this slice? Should the code be copyable/kept somewhere? | Customer loses the only handle to the order. | No | business | Open (owner) | |
| Q-S8 | AU-Q1 (ADR-0014): 5 accepted orders per phone per 24 h. Does a cancelled order count? Is the limit acceptable for a family ordering several times? | TC-49 expected values. | No | business | Open (owner) | |
| Q-S9 | BR-12: no retention period. The device draft (24 h) and backups also hold personal data. Untestable until a period exists; confirm that no test is expected in this slice. | BR-12 has no AC. | No | business | Open (owner) | |
| Q-S10 | Privacy (PRD NFR): "tell the customer what is collected and why before confirmation". UI `REVIEW_PRIVACY` names name, phone, address only; the note is also collected, and a draft is kept on the device. The first data entry (S-7) comes before the sentence (S-8). Sufficient? | PRD NFR cannot be marked Pass without a rule. | No | business | Open (scribe-requirements) | |
| Q-S11 | FR-9 lists the content of the review; AC-14 only tests the total. Is the order of the lines or the format of money and dates (for example `{date}`) a requirement? Date display format is in neither the PRD nor the UI. | Tests compare text; which format is correct? | No | business | Open (scribe-requirements, canvas-ui) | |
| Q-S12 | AC-21 "any screen or error message is Vietnamese": system-owned text (OS back label, keyboard, share sheet, permission alerts, store text) follows the device language. Is only app-owned text in scope? | Makes AC-21 testable. | No | business | Open (scribe-requirements) | |
| Q-S13 | AC-1 requires "only the logo", UI adds 1.0 to 2.0 s (proposed). Treat the numbers as requirements or as tolerance? | TC-101, TC-165 limits. | No | business | Open (scribe-requirements, canvas-ui) | |
| Q-S14 | Verdict rule: "all Must ACs pass". AC-17 (FR-12 Should), AC-26 (FR-18 Should) are tied to Should requirements. Confirm that failing them does not block a Pass verdict. | Verdict criteria. | No | business | Open (scribe-requirements) | |

### 9.2 UI questions (canvas-ui)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-U1 | Contradiction: UI 5.1 says leaving S-5 with back discards flow data, S-9 Home clears it, and S-2 "Place order" goes to S-5 with no cake chosen. ADR-0011 persists the draft on every change, restores it when "Place order" is tapped, and replaces it silently when a cake detail starts an order. Which is right, and is a silent loss of a restored draft acceptable? | FR-15 tests TC-122, TC-141, TC-143, TC-266. | No | technical | Open (canvas-ui, atlas-architect) | |
| Q-U2 | The stepper maximum is not in the UI (TQ-5 answered by ADR-0009: 99). What happens at 99 (plus disabled? message?) | TC-135, TC-140. | No | technical | Open (canvas-ui) | |
| Q-U3 | Which date does the app use as "today": device date or `server_date` from the API? UI 5.6 says "today"; api.md says clients use `server_date`. | TC-153; device clock wrong. | No | technical | Open (canvas-ui) | |
| Q-U4 | Keys missing: `ERR_PRODUCT_UNAVAILABLE`, `ERR_SLOT_UNAVAILABLE`, `ERR_RATE_LIMITED` (API-Q1). With 429 and Retry-After up to an hour, `ERR_SERVER` ("try again") misleads. Which text and behaviour? | TC-155, TC-156. | No | technical | Open (canvas-ui) | |
| Q-U5 | Input limits for name (100) and address (250): what feedback does the customer get when typing or pasting beyond the limit (silent cut, counter, message)? No message key exists. Also IDEMPOTENCY and `VALIDATION_FAILED` fields other than the listed keys show `ERR_SERVER` on S-7: acceptable? | TC-158, TC-30. | No | technical | Open (canvas-ui) | |
| Q-U6 | `MSG_PRICE_CHANGED` is still PENDING; owner decision is now final (409 `PRICE_CHANGED`, customer re-reviews). Final text; does the review highlight changed lines; is confirm enabled at once; does the retry use the same idempotency key? | TC-127, TC-43. | No | technical | Open (canvas-ui) | |
| Q-U7 | S-2 Error state disables all four buttons, but ADR-0011 serves cached data and only shows Error without cache. Update UI 5.2 and 5.3 to the cache rules (TQ-3, TQ-7 answered). What does S-1 wait for: nothing, or the catalog? | TC-132, TC-145, TC-165. | No | technical | Open (canvas-ui) | |
| Q-U8 | Android system back (and predictive back) during sending on S-8, and during the S-8 inert state: ignored or cancel? iOS swipe-back is disabled during sending? | FR-16 on Android, TC-266. | No | technical | Open (canvas-ui) | |
| Q-U9 | Orientation: portrait-only or rotation allowed on Android? Tablets and foldables? UI is silent (ADR-0005 says iPhone only for iOS). | TC-267. | No | technical | Open (canvas-ui) | |
| Q-U10 | After a draft restore the date may be past or full, prices stale. Does the app re-check the restored date and prices on entry to S-6 and S-8, and does it show `DATE_CLEARED`? | TC-141, TC-142. | No | technical | Open (canvas-ui, atlas-architect) | |
| Q-U11 | Placeholders `{from}` and `{to}` in `DATE_HINT_RANGE` are not in the placeholder list (UI section 1). Format of dates in `{date}` messages (weekday?)? | Text assertions. | No | technical | Open (canvas-ui) | |
| Q-U12 | Unavailable date styling: a date that is both too soon and full, or beyond the horizon — which style and spoken reason? (see also Q-A4) | TC-10, TC-110, TC-111. | No | technical | Open (canvas-ui) | |

### 9.3 Architecture and API questions (atlas-architect)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-A1 | Contradiction: architecture.md names TypeScript, Node.js, Fastify, zod; ADR-0001 to 0004 and ADR-0005, ADR-0010 are still "Proposed". The owner decided Swift Vapor, PostgreSQL, iOS 17, API 26 and the 409 price rule. Update architecture.md, ADRs, api.md (remove "pending" notes), order-lifecycle.md and repository layout (`ios/`, `backend/`). | Test tooling, commands, fixtures and CI depend on the stack. | Yes (for execution) | technical | Open (atlas-architect) | |
| Q-A2 | Is there a time between catalog fetch and order for `settings` (lead days etc.) to change? Are `settings` and `max_qty_per_cake` used by the apps instead of constants? | UI uses `{min}`, `{days}`, `{max}` from configuration. | No | technical | Open (atlas-architect) | |
| Q-A3 | `GET /v1/availability` with unknown query parameters (for example `slot_id`): ignored or `VALIDATION_FAILED`? The rule "unknown fields rejected" is stated for requests (bodies) only. | TC-8, TC-9. | No | technical | Open (atlas-architect) | |
| Q-A4 | Reason precedence in availability when several reasons apply; `TOO_FAR` is defined but never returned in the list (dead value); is the list for dates beyond horizon absent by design? | TC-10; untestable enum value. | No | technical | Open (atlas-architect) | |
| Q-A5 | Unknown (never existing) `district_id`: `DISTRICT_UNSERVED` 422 or `VALIDATION_FAILED`? Unknown product/slot are 409, unknown district 422: why the difference? | TC-26, TC-46. | No | technical | Open (atlas-architect) | |
| Q-A6 | `Idempotency-Key` must be a UUID v4: is v1 or other version rejected? Is `X-App-Version` validated as semver? Is there a minimum supported app version / force-update path (api.md section 6 gives none)? | TC-40. | No | technical | Open (atlas-architect) | |
| Q-A7 | Is `expected_total_vnd` part of the normalised request hash for idempotency? After `PRICE_CHANGED` the client retries with a new total: same key or new key? If an order exists and a replay arrives with a changed total, is it replay or `IDEMPOTENCY_KEY_REUSED`? | TC-41, TC-43. | No | technical | Open (atlas-architect) | |
| Q-A8 | Rate limits are checked before the idempotency lookup (check order step 1 before 3). A legitimate retry after a timeout can get 429 or 503 `ORDERING_PAUSED` instead of the stored order. Intended? Do rejected requests count to the 10 per hour? Carrier-grade NAT puts many customers behind one IP (not researched); is 10 per hour per IP too low? | TC-42, TC-48; honest customers blocked. | No | technical | Open (atlas-architect) | |
| Q-A9 | Per-phone limit "5 accepted orders per 24 h": window rolling or calendar day; do cancelled orders count; is it checked before capacity inside the same transaction (race of two orders for the 5th slot)? | TC-49. | No | technical | Open (atlas-architect) | |
| Q-A10 | With `ORDERING_ENABLED=false`, do catalog and availability still answer, and what does the app show (message `ERR_SERVER` only)? Customer cannot tell that the shop is closed for ordering. | TC-53. | No | technical | Open (atlas-architect, canvas-ui) | |
| Q-A11 | Unspecified error cases: malformed JSON, wrong Content-Type, empty body, unsupported method, unknown path (envelope and codes), `expected_total_vnd` missing/negative/non-integer, unknown `Accept`. Add codes. | TC-57. | No | technical | Open (atlas-architect) | |
| Q-A12 | `zalo_contact`: "digits in international form, or an official account id" — two formats; which one for the seed, and the validation rule for the value? | TC-69, AC-3. | No | technical | Open (atlas-architect) | |
| Q-A13 | `server_date` and the order date use the shop time zone (Asia/Ho_Chi_Minh). How is the clock made injectable for tests (E-1), and is the test hook excluded from production builds? | All date-rule cases. | Yes (for execution) | technical | Open (atlas-architect, forge-dev) | |
| Q-A14 | The capacity row lock plus a per-phone check: a deadlock or long wait is described as impossible; confirm the timeout when the lock waits (client timeout 10 s, server timeout?) and the behaviour when the lock wait times out. | TC-19 under load. | No | technical | Open (atlas-architect) | |
| Q-A15 | Reconciliation query and the "CHECK `cakes_accepted <= capacity_limit`" after the limit is lowered (TC-63): is `capacity_limit` updated in the same UPDATE as stated, and can the row violate the CHECK after a limit decrease? | TC-63, TC-70. | No | technical | Open (atlas-architect) | |
| Q-A16 | Store-side requirements (S-3 unverified) and privacy page: is `/privacy` linked from the app? UI has no link. | TC-67. | No | technical | Open (atlas-architect, canvas-ui) | |

### 9.4 Developer questions (forge-dev)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-P1 | Provide the dev guide and update `CLAUDE.md` (it describes the iOS 15 multiplatform template and ddagent, with no backend or Android). Which commands run backend, iOS and Android unit, integration and UI tests? | Section 1 cannot name commands. | Yes (for execution) | technical | Open (forge-dev) | |
| Q-P2 | Confirm environment items E-1 to E-12 (clock, seed, flags, hooks for collisions and database failure, stub backend, accessibility ids, fixtures). | Without them most edge cases cannot run. | Yes (for execution) | technical | Open (forge-dev) | |
| Q-P3 | Seed text: avoid the word "mẫu" and any visible sample marker in app-visible values (Q-S6) while keeping `is_sample = true` in the data source. | AC-29. | No | technical | Open (forge-dev) | |
| Q-P4 | Which server-side logs exist for TC-65 and can a test read them? | No personal data in logs. | No | technical | Open (forge-dev) | |

### 9.5 Cross-document items observed (no question, for information)

- AC-3 and AC-17 (opening Zalo and the dialer) cannot be executed on simulators; real-device results are required before release (ADR-0015, deployment.md launch checklist).
- AC-16 (unique codes) cannot be proven by sampling; unique index plus TC-14 and TC-64 are the evidence.
- UI "Error" states for S-9 contact buttons depend on the OS reporting a failed open; behaviour with Zalo not installed is not an error (opens a web page).
- design-system.md was not reviewed in detail in this early pass.

### Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.7 | 2026-10-27 | Split of the report into the index and eight parts under `place-order-tests/` for the 200-line file size rule; content, TC ids, D ids, section numbers and verdicts unchanged (the QA test files named in earlier rows were split the same way: `CatalogSupport.swift` into `CatalogJSON.swift`, `CatalogSlice1.swift`, `CatalogApp.swift`; `ReviewEdgeTests.swift`, `DatabaseTests.swift`, `StaticContentTests.swift`, `CatalogContractTests.swift`, `CatalogFailureAndLimitTests.swift` into one class or topic per file, 177 test methods before and after). |
| 1.6 | 2026-10-27 | Slice 1 verdict round 6 on 0aa9b8c: section 4.7, verdict Conditional, D-15 to D-20 Fixed on CI evidence; TC-133, TC-134 (and mirrors TC-233, TC-234) updated from the pre-v1.4 rule (Error with fewer than four cakes) to PRD v1.4 (BR-13, AC-32 to AC-34: show the active cakes, Error only at zero). |
| 1.5 | 2026-10-26 | Round 5, slice 1 backend retest on a934ae8: QA package adapted to `SHOP_ID`, `TRUST_PROXY`, ADR-0017 and api.md v1.6; section 4.6 (results of the 17 expected-fail tests, TC-S1-30 to TC-S1-44, AC-32 to AC-34 mapping, code review); defects D-15 to D-20, DOC-11, DOC-12; DOC-1 to DOC-8, DOC-10 closed; GitHub CI run read; verdict Conditional. |
| 1.4 | 2026-10-26 | Slice 1 early execute mode on e9c097b: section 4.5 (mapping of AC-1 to AC-5, AC-21, AC-27, AC-29 and TC-1 to TC-3, TC-50, TC-51, TC-54, TC-57, TC-62, TC-66, TC-67, TC-69 to executable tests or manual client cases, TC-S1-01 to TC-S1-29), QA files `CatalogSupport.swift`, `CatalogContractTests.swift`, `CatalogFailureAndLimitTests.swift`, `StaticContentTests.swift`, round 4 results, document findings DOC-1 to DOC-10, no verdict. |
| 1.3 | 2026-10-26 | Round 3, slice 0 on fbdaafe: D-9 test updated to api.md v1.5 (404), D-3, D-9 to D-13 retested and Fixed, D-7 text corrected, new D-14 (QA test Linux compile error seen in CI, fixed locally), TC-93 updated, results and verdict updated. |
| 1.2 | 2026-10-26 | Round 2, slice 0 on b613c6d: QA package adapted to `AppServices`, `MigrationConfig`; D-1 to D-8 retested (6 fixed, D-3 still open, D-7 fixed); new D-9 to D-13; TC-88 to TC-98 added (`ReviewEdgeTests.swift`); results columns now show round 1 / round 2; verdict conditional. |
| 1.1 | 2026-10-26 | Round 1, slice 0 (execute mode) on f940495: section 4.4 (slice-0 mapping, TC-71 to TC-87), QA package `backend/Tests/qa/` (68 tests), results in section 6, defects D-1 to D-8 in section 7, slice-0 verdict Fail, TC-59 second-cancel wording corrected. |
| 1.0 | 2026-10-25 | First version (Draft, early mode: no code). 70 API cases (TC-1 to TC-70), 65 iOS cases (TC-101 to TC-165), 67 Android cases (TC-201 to TC-267, of which TC-201 to TC-265 mirror iOS and TC-266, TC-267 are Android-only); all results Not run. Traceability matrix for AC-1 to AC-29. Environment needs E-1 to E-12. Open questions Q-S1 to Q-S14, Q-U1 to Q-U12, Q-A1 to Q-A16, Q-P1 to Q-P4. |
