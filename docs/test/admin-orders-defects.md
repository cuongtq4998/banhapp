# Admin Orders: Defect Report (round 1)

| Field    | Value |
| -------- | ----- |
| Version  | 1.0 |
| Date     | 2026-11-01 |
| Commit   | 6852302 (feature/admin-orders) |
| Owner    | probe-qa |
| See also | [admin-orders-test-plan.md](admin-orders-test-plan.md) (parts 09, 10, 11, 12) |

Severity: high = wrong result or data loss in a Must flow; medium = a Must AC fails or cannot be proven; low = safe failure, hardening or wording. Owners: forge-dev (code), atlas (system documents), canvas-ui (UI spec), scribe (PRD). No high-severity defect is open. [v1.0 | 2026-11-01]

## Defects

### D-1 (medium, backend): AC-13 / FR-8, the store-review account does not exist

- Steps: set `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` (named in deployment/04) and try to sign in as `review.demo@example.com`; search `backend/Sources` for the variables; list `GET /v1/admin/orders` after setting `account.kind = 'review'` by SQL.
- Expected (AC-13): review account signs in with a fixed code as staff and sees exactly 3 demo orders and no real one; no notification; demo orders change no limit; switched off when the switch is off.
- Actual: no code reads those variables; there is no sign-in path with a fixed code and no seeding of 3 demo orders. The pieces below it exist and pass: `kind = 'review'` accounts, `is_demo` rows invisible to real accounts and the only rows for review accounts (BE OrderWindowTests), no push to review accounts (BE PushOnOrderTests), no capacity effect of demo orders (BE DemoCapacityTests, migration 0005). `dev-guide.md` also lists the review sign-in as "not built".
- Owner: forge-dev. Alternative: scribe records that AC-13 is deferred until the store review is scheduled (owner decision).
- Evidence gap: G-1 in part 10.

### D-2 (medium, backend, Android, iOS): push was never run against a real service, and the Android build cannot send or receive it

- Steps: read `android/admin/build.gradle.kts` lines 56 to 60 (`src/pushFcm` absent, `src/pushOff` used, push stays off); read `backend/Sources/App/Services/Admin/Push` and `Http/Outbound/` (ApnsPushSender, FcmPushSender tested with a fake transport only).
- Expected (AC-42, 43, 44): a stored order reaches every signed-in phone that allowed notifications within 60 seconds.
- Actual: server logic, payload privacy, retries, token life cycle and the client registration/toast/tap behaviour are proven against fakes (BE Push/, QA AdminPushTests, iU/aU/aI push tests). The two outbound clients were written from public documentation and never ran (dev-guide B7 note, DP-Q4). An Android release has no token provider. iOS needs an Apple Developer Program account (money, not approved).
- Owner: forge-dev (write `src/pushFcm` when a Firebase project exists), orchestrator and owner (credentials, cost). Not a code error; a condition for go-live. Evidence gap: G-3.

### D-3 (low, backend): cancelling an order against a smaller `day_load` row gives 500

- Steps (QA AdminCancelRaceTests::TCB67): store a New order of 4 cakes for date D, give D a `day_load` row with `cakes_accepted = 1` (reachable only by manual SQL), `POST /v1/admin/orders/{code}/status` `{"expected_status":"New","to_status":"Cancelled","cancel_reason":"cannot_deliver"}`.
- Expected: either success (floor at 0, as before migration 0003) or a clear 409/422; never a bare 500.
- Actual: 500 `INTERNAL_ERROR` (the CHECK `cakes_accepted >= 0` refuses the release in the trigger). Safe: the transaction rolls back, the order stays New, `day_load` unchanged. A missing row works (200). Normal flows cannot reach this state; the removal of the GREATEST floor in 0003 is deliberate (the cancel gives the cakes back exactly once, repeat changes nothing).
- Owner: forge-dev (optional hardening: map to a logged 409 or clamp), atlas (record the decision).

### D-4 (low, backend and deployment docs): debug and trace log levels write personal data and credentials

- Steps (QA AdminLogDebugLevelTests::TCB96c, and a trace-level run): start the server with `LOG_LEVEL=debug`, sign in, list orders with `?q=<name>`; with `trace`, send any admin request.
- Expected (BR-7, api/05 section 9 "no e-mail address, token, code or customer data in logs"): holds at the default level.
- Actual: at `info` (default) no personal data or secret appears in the log (QA AdminLogPrivacyTests::TCB96). At `debug` the PostgreSQL driver logs queries with bound values: e-mail address, customer name and phone appear. At `trace` SwiftNIO logs the decoded request head: the `Authorization` header and the query string appear. No code, pepper or refresh token appeared at `debug`.
- Owner: atlas (state in deployment/01 that `LOG_LEVEL` must stay `info` or higher in production), forge-dev (optionally refuse `debug` and `trace` when `APP_ENV=production`).

## Findings that were not defects

- The 18 failures of the old QA run: 17 README listing messages (the README is right: one glob row names all 17 `order-error-*.json` files; the test was too strict) and 1 runner error "Unknown command QATests.xctest" (harness: `app.startup()` parsed the xctest argv). Both repaired in `backend/Tests/qa`. No README change is needed.
- Accepted design risk (R-3 / O-2): three code requests an hour per address can block the owner's own code requests for an hour. Documented in auth.md; operator recovery exists.
- O-3 to O-5 in part 11 (form-encoded body accepted on the status route, bidi characters refused in search, bare head without body bytes gets no answer).

## PRD and document inconsistencies for scribe (X-n)

| ID | Where | Inconsistency | Suggested fix |
| -- | ----- | ------------- | ------------- |
| X-1 | FR-7, BR-13, AC-12 (PRD parts 02, 03, 04) | Say "a phone the owner has not used before". The built and documented rule (architecture/09 TQ-13, api/05 10.2, ADR-0022 v1.3) is "a phone on which the owner has no signed-in session at that moment" (no unrevoked, unexpired session of the owner with the same installation id). The owner signing out and in again on the same phone does get a notice (BE NewDeviceNoticeTests::OwnerSignedOutAndBackInOnTheSamePhoneIsNewAgain). | Use the session wording in FR-7, BR-13 and AC-12 and add the sign-out-then-in example to AC-12 |
| X-2 | PRD parts 02 to 06 | Headers read "(PRD v1.5)" and "Based on ... v1.5" while the PRD is v1.6; FR-4 and AC-7 still start "Decided P-2 (Q-26 ...)"; BR-4, BR-11 and the NFR carry "(proposed ...)" labels although the PRD is approved and A-10 says proposed values are author defaults; `07-open-questions.md` TQ-9 is still "Open" | Refresh labels; close TQ-9; keep one sentence that values are approved defaults |
| X-3 | PRD BR-11 vs AC-40 / clients | BR-11 gives a delivery fee range starting at 1 ("1 to 10 000 ..."), AC-40 refuses fee 0; both apps refuse a fee of 0 (aU DeliveryTest::aFeeOfZeroIsRefused...). A shop that wants free delivery to one district cannot express it. Confirm that fee 0 is intended to be refused | Business confirmation |
| X-4 | docs/test and design | `docs/design/admin-orders/11-traceability-questions-changelog.md` still says "AC-11, AC-12, AC-13, AC-47 and FR-6, FR-7, FR-8 have no UI by design"; correct for AC-13 only until D-1 is decided (the review account needs no screen, but its sign-in is the normal screen) | canvas-ui: no change unless D-1 adds UI |

[v1.0 | 2026-11-01]

## Round 37: QA package migration to the six statuses [v1.1 | 2026-11-02]

| ID | Route | Steps | Expected | Actual |
| -- | ----- | ----- | -------- | ------ |
| D-37-1 | dev | Run `cd backend/Tests/qa && QA_ALLOW_DB_MUTATION=1 swift test` on the backend stage branch; test `ContractFixtureTests.testExtra_FixtureReadmeListsEveryFixture`. | `contracts/fixtures/README.md` describes every fixture in `contracts/fixtures/admin/`. | Seven fixtures are not listed: `order-detail-fee-corrected`, `order-detail-delivery-started-free`, `order-detail-delivery-started`, `order-detail-delivery-date-scheduled`, `error-validation-fee-invalid`, `error-validation-expected-date-too-far`, `error-order-state-changed-fee` (all `admin/*.json`). The test stays active; it is a documentation gap, not a behaviour defect. |

Test-side notes (not defects): the cursor of ADR-0029 v1.8 is unsigned, so the cursor tamper test now breaks the version prefix instead of the last character; the status route answers `FIELD_NOT_ALLOWED` (api/09 10.13.2 note) where the old test expected `REASON_NOT_ALLOWED`.
