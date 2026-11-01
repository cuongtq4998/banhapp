# Admin Orders Test Plan: Execution, backend and contracts (part 11)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.0). Holds: round 1 environment and results of the backend, QA and contract packages; mapping of plan cases to the executable QA tests; the 18 known failures; performance numbers; observations. Commit under test: 6852302 (`feature/admin-orders`, worktree `17-probe-qa`). [v2.0 | 2026-11-01]

## 11.1 Environment

macOS 27 (arm64), Xcode 27.1 RC toolchain, Swift 6.4, PostgreSQL 16.15 on 127.0.0.1:5544 (throwaway databases `qa_admin_1` for the QA package, `qa_admin_2` for the main suite; database `banh` untouched), loopback only. Mail and push use the recording senders (`EMAIL_PROVIDER=recording`, `PUSH_PROVIDER=recording`); the clock is injected. QA tests start the real application on a loopback port and talk HTTP (URLSession and a raw socket); they read the database only for assertions and seeding. `DATABASE_MIGRATION_URL=postgres://banh@127.0.0.1:5544/<db>`; `QA_ALLOW_DB_MUTATION=1` for the older data-change tests. [v2.0 | 2026-11-01]

## 11.2 Results (round 1)

| Package | Command | Executed | Failed | Skipped |
| ------- | ------- | -------- | ------ | ------- |
| Backend (developer tests) | `cd backend && swift test` | 575 | 0 | 0 |
| Contracts (`BanhContracts`) | `cd contracts/swift && swift test` | 26 | 0 | 0 |
| QA package, before my work | `cd backend/Tests/qa && swift test` | 177 | 2 tests (18 failure messages) | 0 |
| QA package, after (4 runs, identical) | same | 230 | 0 | 0 |

The QA package grew by 53 tests, all in `Tests/QATests/Admin/` (cancel race 3, auth abuse 10, role matrix 5, images 6, search and cursor 6, phone limit 5, push 5, log privacy 2, log debug 1, performance 3, status rules 5, fuzz 2); the README test was renamed and widened, the runner test repaired. Clients: part 12. [v2.0 | 2026-11-01]

## 11.3 The 18 known failures: the tests were wrong, the README is right

- 17 messages "order-error-*.json is not described in contracts/fixtures/README.md" (`ContractFixtureTests`). README line 26 documents the family with one glob row (`order-error-*.json`) that names all 17 members (checked one by one). The old test looked for each full file name. Fixed in the test (`testExtra_FixtureReadmeListsEveryFixture`): a file is described when it is named, or when it matches a glob row and its short name is in that row; the same check now also covers `contracts/fixtures/admin/` (all admin fixtures are described). No README defect. [v2.0 | 2026-11-01]
- 1 runner error "Unknown command QATests.xctest" (`ErrorPipelineEdgeTests.testBodyLimitOverRealHttpWithContentLengthAndChunked`): harness problem. `app.startup()` runs Vapor's default command on the xctest argv. Fixed: the test starts the listener with `app.server.start(address:)` and shuts it down with `await app.server.shutdown()`. The test now runs the real check (8,192 bytes accepted, 8,193 gives 413, Content-Length and chunked) and passes. [v2.0 | 2026-11-01]

## 11.4 Plan cases to executable QA tests (black box, real HTTP, real PostgreSQL)

| Plan case | QA test (class::test) | Result |
| --------- | --------------------- | ------ |
| TC-B84, B83, B81 | AdminCancelRaceTests::TCB84 (cancel racing 6 customer orders at the capacity edge, 10 rounds: day_load equals open cakes, never above 10, never negative); TCB81 (8 parallel cancels: one wins, cakes returned once, one event) | Pass |
| TC-B67 | AdminCancelRaceTests::TCB67 (no day_load row: 200; row smaller than the order: refused safely, see D-3) | Pass (D-3 low) |
| TC-B105, B106 | AdminPerformanceTests::TCB105, 105b, 106 (9,000 orders plus 1,000 open ones: see 11.5) | Pass |
| TC-B01, B14, B15 | AdminAuthAbuseTests::TCB01 (same answer, mail only to registered), TCB14 (30 s wait, 3 an hour, Retry-After at most 3600), TCB15 (new code kills the older) | Pass |
| TC-B08, B09 | TCB08 (5 wrong voids the code, right digits refused, no lock), TCB09 (format errors not counted) | Pass |
| TC-B10 to B13 | TCB10 (refresh reuse revokes family), TCB11 (grace window does not slide), TCB12 (deactivated staff cannot refresh, no mail, owner protected), TCB13 (token abuse, expired token) | Pass |
| TC-B23 | TCB23 (sign out others keeps this phone) | Pass |
| TC-B22 | AdminRoleMatrixTests::TCB22, 22b, 22c, 22d, 22e (every `/v1/owner` route: staff 403, anonymous 401, junk 401, owner never 403 or 5xx; every `/v1/admin` route needs a session; own e-mail only on /me; header checks) | Pass |
| TC-B107 to B121 (images) | AdminImageAttackTests::TCB110 to TCB115 (PNG and JPEG served with nosniff; zero byte, GIF, HTML, SVG, EXE, truncated headers refused with nothing stored; dimensions 0, 199, 4,097, 65,535, 2^32-1 refused, 200 and 4,096 accepted; polyglot served as image/png only; exactly 5,242,880 bytes accepted, +1 gives 413 IMAGE_TOO_LARGE; two files, none, many field problems; Content-Length 6 MB refused with 413 after ten body bytes, role (403) and session (401) checked first, 8 KB limit on other routes) | Pass |
| TC-B59 to B62 | AdminSearchCursorTests::TCB59 (code, name, phone forms, NFD), TCB60 (3 to 50 characters, control characters, digits-only rule), TCB61 (d with stroke, horn letters), TCB62 (`%`, `_`, `\`, SQL, script, emoji literal; table intact) | Pass |
| TC-B57, B71 | TCB57 (every code of api/08 11.1, defects listed together, status body codes), TCB71 (120 rows 50/50/20 no repeat, 13 forged or truncated cursors give CURSOR_INVALID, cross-filter and cross-account cursors give no 5xx) | Pass |
| TC-B98 to B104 | AdminPhoneLimitTests::TCB98 (three non-spam reasons free the phone), TCB100 (spam counts for 24 h, then accepted), TCB101 (mix and phone spellings), TCB103 (first reason kept), TCB104 (replay not counted) | Pass |
| TC-B88 to B95 | AdminPushTests::TCB88 (2 of 3 phones get exactly one push of code, cakes, date; no personal text), TCB91 (sign-out, deactivation, sign out others, replay, refusals send nothing), TCB92 (token moves, dead token deleted, failing provider never fails the order), TCB93 (10 invalid bodies 422, DELETE route gone), TCB95 (no reminder push) | Pass |
| TC-B96 | AdminLogPrivacyTests::TCB96, 96b; AdminLogDebugLevelTests::TCB96c (see 11.6) | Pass at info and debug for secrets; PII at debug: O-1 |
| TC-B97 | Dependency scan: no analytics or crash SDK in Gradle files, `libs.versions.toml`, SwiftPM or `BanhAdmin.xcodeproj` (only a comment about an optional Firebase push dependency) | Pass |
| TC-B76 to B82, B64, B65, B68 | AdminStatusRulesTests::TCB82 (16 pairs, only 4 succeed, nothing else changes, capacity untouched), TCB80 (stale view 409 with current order), TCB78 (8 bad reasons, 4 good), TCB68 (D-1: exact repeat after leaving the window gives 200 replay, other call 404, other account 404, same body as unknown code), TCB64 (89 d shown, 91 d not found, old open order listed) | Pass |
| extra: fuzz | AdminFuzzTests::TCB146 (35 hostile bodies on every owner POST, PUT, PATCH route: 0 server errors), TCB147 (wrong content type, verbs) | Pass (O-4) |

[v2.0 | 2026-11-01]

## 11.5 Performance (TC-B105, B106), indicative, one host, loopback

Data: 9,000 orders in the 90-day window (4,500 Completed, 3,500 Cancelled, 800 New) plus 200 Confirmed orders placed 95 days ago and older (1,000 open orders in all). 40 sequential calls each, p95 over HTTP: default list 9 ms (12.5 KB), status=all 23 ms, status=Completed 15 ms, search by name 3 ms, by phone fragment 9 ms, by code fragment 3 ms, empty search 11 ms, today filter 6 ms, detail 3 ms, status change 4 ms (30 calls). Targets: 500 ms list, 1 s status change. Plan of the default list query: `Index Scan using customer_order_open_idx`, execution 0.07 ms, no sequential scan. Not covered: free-tier host, cold start, concurrent load. [v2.0 | 2026-11-01]

## 11.6 Observations (not defects of the contract)

- O-1 Log level. At the default `info` the log holds no address, token, code, customer name, phone, address, note, search text or cursor. At `debug` the PostgreSQL driver logs queries with bound values (e-mail address, customer name and phone appear); at `trace` SwiftNIO logs every request head including the `Authorization` header and the query string. Secrets (codes, pepper, refresh tokens) never appeared at debug. See defect D-4 (low).
- O-2 Three code requests an hour per address also hit the owner (R-3): an outsider who knows the owner's address can keep the owner from signing in for an hour with 3 requests; limited only by 20 requests an hour per client address. Documented and accepted in `auth.md` (operator recovery, A-7).
- O-3 A request head that announces a 6 MB upload but sends no body bytes gets no answer until bytes arrive (transport behaviour); with ten body bytes the 413 is immediate. Slow-body timeouts were not tested.
- O-4 The status route also accepts a form-encoded body (`expected_status=New&to_status=Confirmed`) although the contract says JSON. Bearer authentication, no cookies, so no cross-site risk. Harmless; mention for completeness.
- O-5 `q` with a Unicode format character (bidi override) is refused as a control character. Strict but safe.
- O-6 Cancelling an order whose `day_load` row holds fewer cakes than the order gives 500 `INTERNAL_ERROR`; nothing changes (D-3).
