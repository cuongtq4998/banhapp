# admin-orders: hand-off status

[v3.0 | 2026-11-02] Written so work can continue on another machine. Replaces v2.x. Work was stopped by the owner in the middle of two slices.

## Where things are

- `feature/admin-orders` (pushed): everything that is verified and merged: backend, contracts, documents. Pull request #2 (`feature/admin-orders` into `feature/place-order`) is open and **not merged**; pull request #1 (`feature/place-order` into `main`, draft) is **not merged**; #2 is stacked on #1. The owner decides both merges.
- Three **stage branches are pushed** for the client work that is not merged yet (stage branches are normally local; they are pushed only for this hand-off):

| Branch | Holds | State |
| --- | --- | --- |
| `stage/admin-orders/43-forge-ios` | iOS admin: models, API, view models, strings, list chips, detail screen, sheets, Debug stub, UI tests | Build succeeds. 108 unit tests passed (before the screens). **10 of 13 new UI tests fail, cause not found.** Not verified after the last commits. |
| `stage/admin-orders/43-forge-android` | Android admin: models, API, view model, list, stepper, action bar, sheets, delivery card, stub, instrumented tests | **Functionally done.** 332 JVM tests pass; 80 instrumented tests run on an emulator: 68 pass, 12 assumption skips, 0 real failures. |
| `stage/admin-orders/46-forge-android-customer` | Android customer tracking, slice S11a (data, view model, texts, tests) | **Written, never built or tested.** Interrupted. |

- Read first: `docs/product/admin-orders.md` (v1.14), `docs/product/place-order.md` (v1.13) and its part `place-order/08-order-tracking.md`, `docs/system/order-process.md` (v1.6), ADR-0033, ADR-0034, `docs/system/api/09-order-process-api.md`, `api/10-customer-order-lookup.md` (v1.5), `data-model/06` and `07`, `docs/design/admin-orders/12` and `13`, `docs/design/place-order-ui/13` and `14`, `docs/design/design-system/08`, `docs/engineering/db-backup.md`, `lookup-tests.md`.

## The order process change (owner decisions of 2026-11-02)

- Steps: Received, Processing, Delivery date scheduled, Delivery started, Finished, plus Cancelled. Cancel only from Received and Processing; a customer refusing at the door is handled outside the app.
- The district fee is an estimate. The real fee is entered at "Start delivery" (required, 0 allowed, 0 to 10 000 000), correctable by staff or owner until Finished (recorded). The customer never sees a total before the real fee is known.
- The expected delivery date is set at "Schedule delivery" (today to today + 7, Vietnam calendar), movable any number of times (recorded); red marks, badge and list order use it when set; it never moves the daily capacity.
- Customer order tracking (phone number only, no sign-in, no push, newest first, order code and cake names shown, phone masked, district only) is approved (place-order part 08). Accepted risks: anyone who knows a phone number sees its orders; an attacker can use up a victim's lookup budget.
- Assumptions to confirm: Q-35 (no automatic message when the date moves), Q-36 (old statuses map New to Received, Confirmed to Processing, Completed to Finished), Q-O8 (30 x 24 hours window, never shown to customers), Q-O11 (a cancelled order shows "Cancelled" plus the shop contact).

## State by component

| Component | State |
| --- | --- |
| Backend | **Done and merged.** Migrations `0008` and `0009`, six-status model, status route with date and fee, `PUT /expected-delivery-date`, `PUT /delivery-fee`, list date, badge, `last_change`, `delivery_fee_entry`, versioned list cursor, customer lookup `POST /v1/orders/lookup`. Backend suite 738 tests, QA package 230 tests, contracts package 32 tests, 0 failures on PostgreSQL 16 (2026-11-02). |
| Contracts | **Done and merged.** 20 admin fixtures, 12 customer lookup fixtures, `OrderLookupResponse` types in `BanhContracts`. |
| iOS admin | Stage branch, see above. |
| Android admin | Stage branch, see above (done except the live run). |
| Android customer | Slice S11a on a stage branch, unverified. Compose screens S-10 and S-11, the "Follow this order" shortcut and instrumented tests not started. |
| iOS customer | **Not started** (tracking screens S-10, S-11, shortcut). |
| QA | Black-box cases for the new endpoints and the legacy mapping read are planned (plan v2.2) and not executable yet. |

## Next steps, in order

1. **iOS admin, debug the 10 failing UI tests** (branch 43-forge-ios). Facts: 9 fail with `admin.detail.code did not appear` right after tapping a list row; the first row (`BT-7K3M9Q`) opens, the second (`BT-9D6R3T`) does not; no crash. Suspect: the stub answer for that order is missing or mistyped for a field the new decoder requires. A new unit test `StubOrderDecodeTests` (decode the stub answer of every order) was added at the end and has not been run. Then: add the 409 fee-conflict banner (`A_FEE_CONFLICT`, `admin.order.feeConflict`), show `FEE_CORRECTION_NOT_ALLOWED` in the correction sheet, re-run the unit and UI tests, update `OperatingFlowLiveTests.swift` (it finishes an order right after process: it needs the schedule and fee steps).
2. **Android customer S11a**, build and test it (`./gradlew :app:testDebugUnitTest`), fix, then the Compose screens S-10 and S-11 and the shortcut on the home and confirmation screens (design `place-order-ui/13`, `14`).
3. **iOS customer**: the same tracking screens.
4. **Merge the client branches**: make an integration worktree from `feature/admin-orders`, merge the stage branches, run every check below, scan for secrets, then fast-forward `feature/admin-orders`. The backend and both admin apps must ship together (the old admin apps break on the new statuses); take a `pg_dump` first.
5. probe-qa: executable black-box cases for the new endpoints, the lookup security tests and the legacy mapping; update the test plan with results.
6. Small document items: canvas-ui: a copy key for `EXPECTED_DATE_UNCHANGED`, confirm the Android fee confirm button (design says enabled so errors can be listed; the code disables it until valid), tones for the new statuses; atlas-architect: make the legacy mapping rule the same on iOS (history only) and Android (everywhere); scribe: stale "Draft" and version strings in a few headers; tag form `admin.orders.row.expected.<code>` (design 13 says without the code).

## Checks before any merge

- Backend: `cd backend && DATABASE_MIGRATION_URL=postgres://<user>@127.0.0.1:<port>/<fresh db> swift test` (without the variable the database tests are skipped, not run).
- QA package: `cd backend/Tests/qa && QA_ALLOW_DB_MUTATION=1 DATABASE_MIGRATION_URL=... swift test`. Contracts: `cd contracts/swift && swift test`.
- Migrations as CI does: `cd backend && APP_ENV=local PORT=8080 DATABASE_MIGRATION_URL=... swift run App migrate --yes`, then `backend/db/seed/sample.sql` twice.
- Android: `export JAVA_HOME=<JDK 17> ANDROID_HOME=<sdk>`; `cd android && ./gradlew :admin:testDebugUnitTest :core:common:testDebugUnitTest :app:testDebugUnitTest :admin:compileDebugAndroidTestKotlin`; instrumented: `ANDROID_SERIAL=<emulator> ./gradlew :admin:connectedDebugAndroidTest` (assumption skips are not failures; the live e2e steps need `e2eLive=true`).
- iOS: Xcode 26.x only (CI has no Xcode 27: never accept the project format upgrade); `-parallel-testing-enabled NO`; the tests use Swift Testing: read the line `Test run with N tests`, not the XCTest `Executed` line.
- A test that checks a query plan must create its own data and run `ANALYZE` first.

## Notes about the machine this ran on (not in the repository)

- **`~/.cache/derived-data-pool/bin/dd-build.sh` was extended on that machine** (with the owner's approval) to accept `--project P.xcodeproj` or `--workspace W` (default stays the other project's workspace); with `--project` it makes an empty `SourcePackages` instead of copying the seed. A hook there blocks raw `xcodebuild build|test` and requires the wrapper. Command used for BanhAdmin tests: `dd-build.sh --project ios/BanhAdmin.xcodeproj --scheme BanhAdmin --destination "platform=iOS Simulator,id=<id>" test -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO -only-testing:BanhAdminTests`. On another machine without that hook or wrapper, plain `xcodebuild` per `CLAUDE.md` works.
- `ddagent run` builds iOS apps (`ddagent lane acquire --target "iPhone 17"`, then `ddagent run --lane <id> --project ios/BanhAdmin.xcodeproj --scheme BanhAdmin --no-open`) but has no test command. Its Android runs failed with "JDK 17+ not found" (JDK discovery, even with `JAVA_HOME` set): the emulator was started by hand instead. Release every lane (`ddagent lane release`).
- A throwaway PostgreSQL 16 was used on a local port with a data directory outside the repository. A slot of about 11 GB per iOS worktree builds in the pool; the disk had about 38 GiB free: remove old slots when you finish.
- `LOOKUP_KEY_SECRET` must be set on the real host (same value on every instance), see `deployment/03` section 7.2.

## Open items for the owner

1. Confirm that the pseudonymous ids (`account_id`, `device_session_id`) kept in `security_event_archive` past 180 days are acceptable (otherwise drop or null `account_id` there).
2. The assumptions Q-35, Q-36, Q-O8, Q-O11 above.
3. Go-live gates: paid hosting, domain, store fees and Firebase are not approved; retention question Q-O4 is open; real push (APNs, FCM) and real e-mail are unverified; the `pg_dump` step is documented and rehearsed but has no job; the p99 table for the lookup floor is empty.
4. iOS live step 7b (fix not verified; the iOS live flow also needs the new steps), iOS video and screenshots missing, `docs/engineering/dev-guide.md` (190 lines, very long paragraphs) should be split by subject.

## Working rules in force

- Every subagent session runs at most 5 minutes; split work into small slices. Subagents work in their own worktrees; only the orchestrator runs git and merges.
- Every hand-written file has at most 200 lines, including SQL migrations. The repository is public: no secrets or real personal data.
- Every database change is a new numbered migration with a `pg_dump` taken first (owner rule); an applied migration is never edited.
