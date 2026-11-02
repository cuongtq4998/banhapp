# admin-orders: hand-off status

[v2.0 | 2026-11-02] Written so work can continue on another machine. Replaces v1.x.

## Where things are

- Branch `feature/admin-orders` (pushed) holds backend B1 to B7, both admin apps (iOS and Android) as built before the order process change, QA, docs and the live end-to-end tests, plus the new order process on the **backend only** (see below).
- Pull request #2 (`feature/admin-orders` into `feature/place-order`) is open and **not merged**. Pull request #1 (`feature/place-order` into `main`, draft) is **not merged**; #2 is stacked on it. The owner decides both merges.
- Read first: `docs/product/admin-orders.md` (v1.13) and `docs/product/place-order.md` (v1.11), `docs/product/admin-orders/09-order-process-and-delivery-fee.md`, `docs/system/order-process.md` (v1.6), ADR-0033, ADR-0034, `docs/system/api/09-order-process-api.md`, `api/10-customer-order-lookup.md`, `data-model/06` and `07`, `docs/engineering/slice-plan-order-process.md` (the system documents win where they differ), `docs/engineering/db-backup.md`.

## The order process change (owner decisions of 2026-11-02, Q-29 answered)

- Steps: Received, Processing, Delivery date scheduled, Delivery started, Finished, plus Cancelled. Cancel only from Received and Processing; refusal at the door is handled outside the app.
- The district fee is an estimate; the real fee is entered by staff or owner at "Start delivery" (required, 0 allowed, 0 to 10 000 000) and can be corrected by either until Finished (recorded).
- The expected delivery date is set at "Schedule delivery" (today to today + 7, Vietnam calendar), movable any number of times (recorded). Red marks, badge and list order use it when set. It never moves the daily capacity (that stays on the customer's date).
- A customer order tracking screen (phone number only, no sign-in, no push, newest first, order code and cake names shown, phone masked, district only) is **approved** as part 08 of the place-order PRD; the owner accepted the residual risks (anyone who knows a phone number sees its orders; an attacker can use up a victim's lookup budget).
- Assumptions still to confirm: Q-35 (no automatic message when the date moves), Q-36 (old statuses map New to Received, Confirmed to Processing, Completed to Finished), Q-O8 (30 x 24 hours display window, not shown to customers), Q-O11 (cancelled order shows "Cancelled" plus the shop contact).

## State by component

| Component | State |
| --- | --- |
| Backend | **Done and merged**: migrations `0008` and `0009`, six-status model, status route with date and fee, `PUT /expected-delivery-date`, `PUT /delivery-fee`, list date, badge, `last_change`, `delivery_fee_entry`, versioned cursor, fixtures. Backend suite 699 tests, QA package 230 tests, 0 failures on PostgreSQL 16 (2026-11-02). |
| Backend, not built | `POST /v1/orders/lookup` (customer lookup, api/10) with masking, paging, three rate limits, log privacy; `LOOKUP_*` names in `.env.example`. |
| Contracts | Admin fixtures updated (20 files). Swift package tests pass (26). Customer lookup fixtures not written. |
| iOS admin (`ios/BanhAdmin`) | **Not changed**: still reads old status words (OrderModels, OrdersAPI and their tests); needs the six steps, expected date sheet, fee sheet, correction, fee history, unknown status shown as a neutral label. |
| Android admin (`android/admin`) | **Not changed**: same list (OrdersApi.kt and tests). |
| Customer apps | Create-order API is unchanged. Tracking screens (S-10, S-11) and the "Follow this order" shortcut are specified (design part 13 and 14) and not built. |
| QA | Black-box cases for the new endpoints and the legacy mapping read are planned (plan v2.2, parts 13 to 19) and not executable yet. |

## Next slices, in order

1. Backend S5c: customer lookup route (api/10, ADR-0034), then its fixtures and tests.
2. Contracts: `BanhContracts` types for the new order shapes and lookup.
3. iOS admin, then Android admin (the old admin apps break on the new status words: backend and both admin apps must ship together; no rolling deploy; take a `pg_dump` first, see `docs/engineering/db-backup.md`).
4. Customer apps: tracking screens on both platforms.
5. probe-qa: executable black-box cases for the new endpoints, the lookup security tests, the legacy mapping; update the test plan with results.
6. atlas-architect: `api/06` 10.10 still shows old text in places; check the `message_key` of 422 answers (`ERR_SERVER`) against api/08 11.1.
7. Go-live: the migration is not additive: `pg_dump`, test restore, apply `0008` and `0009`, start the new backend only after both succeeded (if `0009` fails the system is unusable; recovery is the restore).

## Open items

1. **iOS 7b (fix not verified).** The step now drags from 20% to 80% of the screen height instead of `swipeDown()`. Re-run live step 7b with `ios/Tools/run-e2e-live.sh` and a new fake phone. The iOS live flow will need to be revised anyway for the new steps.
2. **iOS video** is missing ("Host recording is already in progress" on the iPhone 16 simulator, holder unknown). **iOS step 1 screenshots** were deleted; use a new fake phone (`Live.customerPhone` in `ios/BanhAdminUITests/Live/LiveConfig.swift`).
3. Android admin stub tests: all five pass (74 tests, 12 skipped by assumption). Only the delivery test needed a change.
4. Go-live gates: the purge task is built and verified (migration `0007`, ADR-0032). The owner still has to confirm that the pseudonymous ids (`account_id`, `device_session_id`) kept in `security_event_archive` past 180 days are acceptable. The `pg_dump` step is documented and rehearsed, but has no CI or deploy job. Paid hosting, domain, store fees and Firebase are not approved; retention question Q-O4 is open; real push (APNs, FCM) and real e-mail are unverified.
5. `docs/engineering/dev-guide.md` (190 lines, very long paragraphs) should be split by subject (owner rule: at most 200 lines per file; a split was started and not done). `docs/product/admin-orders/07-open-questions.md` line 25 still says Q-O6 to Q-O12 are partly Draft.
6. place-order slice 4 (launch readiness) is still waiting. Stale `docs/pipeline/*/run.md`; stale worktree `place-order/4-forge-ui-android`.

## Running the backend tests

- PostgreSQL 14 or newer, an empty database per run: `cd backend && DATABASE_MIGRATION_URL=postgres://<user>@127.0.0.1:<port>/<db> swift test`. Without the variable the database tests are skipped, not run.
- QA package: `cd backend/Tests/qa && QA_ALLOW_DB_MUTATION=1 DATABASE_MIGRATION_URL=... swift test` (throwaway database only).
- Migrations as CI does: `cd backend && APP_ENV=local PORT=8080 DATABASE_MIGRATION_URL=... swift run App migrate --yes`, then apply `backend/db/seed/sample.sql` twice.
- A test that checks a query plan must create its own data and run `ANALYZE` first (a fresh database picks other plans).

## Running the live flow again

- Sign-in codes: a code is limited to 3 requests per hour per address, 30 seconds apart; each run needs 2 for the owner and 1 for staff. Use fresh fake phones and addresses.
- Backends: `PUSH_PROVIDER=recording`, `EMAIL_PROVIDER=console`, codes appear in the backend log. Never bind a helper server to `0.0.0.0`.
- iOS: `ios/Tools/run-e2e-live.sh` (set `E2E_LIVE=1` through `TEST_RUNNER_E2E_LIVE=1`). Android: `android/e2e/run-operating-flow.sh` (needs JDK 17 and an AVD; ddagent lanes for emulators). Both are gated, so normal CI is not affected.

## Working rules in force

- Every subagent session runs at most 5 minutes; split work into small slices. Subagents work in their own worktrees; only the orchestrator runs git and merges.
- Every hand-written file has at most 200 lines, including SQL migrations. The repository is public: no secrets or real personal data.
- Every database change is a new numbered migration with a `pg_dump` taken first (owner rule); an applied migration is never edited.
