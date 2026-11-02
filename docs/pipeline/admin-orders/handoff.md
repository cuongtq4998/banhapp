# admin-orders: hand-off status

[v1.0 | 2026-11-02] Written so work can continue on another machine.

## Where things are

- Branch `feature/admin-orders` (pushed) holds backend B1 to B7, both admin apps (iOS and Android), QA round 1, docs and the live end-to-end tests.
- Pull request #2 (`feature/admin-orders` into `feature/place-order`) is open and **not merged**. Pull request #1 (`feature/place-order` into `main`, draft) is **not merged**; #2 is stacked on it. The owner decides both merges.
- Read first: `docs/product/admin-orders*`, `docs/design/admin-orders*`, `docs/test/admin-orders-test-plan*`, `docs/test/admin-orders-defects.md`, `docs/engineering/dev-guide.md` (live-run paragraphs for iOS and Android).

## Live operating flow (customer app + admin app on a real local backend)

| Platform | Result |
| --- | --- |
| Android | 8 of 8 steps pass; video parts 1 to 9 recorded locally (not in the repo) |
| iOS | Steps 1 to 6, owner sign-out, staff sign-in and the log audit pass. Step 7b fails (see below). No video. |

## Open items

1. **iOS 7b (open, fix not verified) [v1.1 | 2026-11-02].** Reading `OrderListViewModel` found no defect; the likely cause is that the e2e step used `swipeDown()`, which can miss the pull-to-refresh zone. The step now drags from 20% to 80% of the screen height. Nothing was compiled or run: re-run live step 7b. Original report: after the owner deactivates a staff member, the staff app sends no request (neither a chip tap nor pull-to-refresh) and stays on the list. The backend log shows nothing from that device. Unit test `OrderListSessionEndedTests` shows a 401 `SESSION_REVOKED` does end the session, so the problem is before a request leaves the app or in the simulator. Next step: manual run with `xcrun simctl spawn booted log stream`, and check `OrderListViewModel` (`reloadIfStale`, `isRefreshing`, `loadTask`). If it is a real defect, fix it in `ios/BanhAdmin`. Android passes the same step.
2. **iOS video** is missing: the recorder prints "Host recording is already in progress" on the iPhone 16 simulator; the holder is unknown.
3. **iOS step 1 screenshots** were deleted by a cleanup; re-running needs a new fake phone (change `Live.customerPhone` in `ios/BanhAdminUITests/Live/LiveConfig.swift`) because the old one is rate-limited for 24 hours.
4. Android admin stub tests [v1.1 | 2026-11-02]: the five tests listed earlier all pass on the emulator (74 tests, no real failure; 12 are skipped by an assumption: 10 live steps need `e2eLive=true`, 2 push tests find the permission already granted). Only `DeliveryStaffFlowTest.theLastActiveDistrictAndSlotCannotBeSwitchedOff` was changed (scroll to the slot toggle before the tap, new `DELIVERY_LIST` tag). The other four passed without a change, so their earlier failures were not reproduced; the cause is unknown (emulator state is the guess).
5. Go-live gates [v1.3 | 2026-11-02]: the purge task (`auth_code`, sessions, security events) is built and verified on PostgreSQL 16.15: full suite 622 tests, 0 failures. Migration `0007_security_event_purge.sql` lets the trigger delete security events older than 180 days and adds the append-only `security_event_archive` (ADR-0032); the purge copies and deletes in one statement. Still open: the `pg_dump`-before-migrate step is a rule in `data-model/05` section 15.1 but has no runbook or CI job; owner to confirm that the pseudonymous ids (`account_id`, `device_session_id`) kept in the archive past 180 days are acceptable; paid hosting, domain, store fees and Firebase are not approved; retention question Q-O4 is open; real push (APNs, FCM) and real e-mail are unverified.
6. Owner question Q-29 (allow a delivery fee of 0) is unanswered; the recommendation is to allow it.
7. place-order slice 4 (launch readiness) is still waiting. Stale worktrees: `agent-a1f0cfa50ac9e6ed4`, `place-order/2-canvas-r4`, `place-order/5-probe-r2`; stale `docs/pipeline/*/run.md`.

## Running the live flow again

- Sign-in codes: a code is limited to 3 requests per hour per address, 30 seconds apart; each run needs 2 for the owner and 1 for staff. Use fresh fake phones and addresses.
- Backends: `PUSH_PROVIDER=recording`, `EMAIL_PROVIDER=console`, codes appear in the backend log. Never bind a helper server to `0.0.0.0`.
- iOS: `ios/Tools/run-e2e-live.sh` (set `E2E_LIVE=1` through `TEST_RUNNER_E2E_LIVE=1`). Android: `android/e2e/run-operating-flow.sh`. Both are gated, so normal CI is not affected.

## Working rules in force

- Every subagent session runs at most 5 minutes; split work into small slices.
- Every hand-written file has at most 200 lines. The repository is public: no secrets or real personal data.
