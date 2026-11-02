# Admin Orders Test Plan: FR to evidence and evidence gaps (part 10)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.0). Holds: FR-1 to FR-27 to evidence, and the list of ACs (or parts of ACs) with no automated evidence. Evidence names are in [part 02](02-traceability-matrix.md) under the ACs listed. Commit 6852302. [v2.0 | 2026-11-01]

## FR to evidence

| FR | Subject | ACs (evidence in part 02) | Status |
| -- | ------- | ------------------------- | ------ |
| FR-1 | Sign in with e-mail and 6-digit code | AC-1, 2, 3, 4 | Evidenced (server and both apps) |
| FR-2 | Stay signed in 7 days, sign out | AC-5, 6 | Evidenced; 7-day idle is logic only (clock tests) |
| FR-3 | Roles owner and staff | AC-8 | Evidenced; Android hiding of Settings for staff has no test |
| FR-4 | Sign out all other phones | AC-7 | Evidenced |
| FR-5 | Staff accounts | AC-9, 10 | Evidenced |
| FR-6 | Sign-in protection (limits, rotation, grace) | AC-4, 11 | Evidenced (QA black box) |
| FR-7 | New-device notice to the owner | AC-12 | Evidenced with the recording sender; real mail never sent; wording item X-1 |
| FR-8 | Store-review account | AC-13 | **Not implemented** (D-1) |
| FR-9 | Order list, marks, window | AC-14, 15, 16, 21, 22, 23 | Evidenced |
| FR-10 | Status and date filters | AC-18 | Evidenced |
| FR-11 | Search | AC-19 | Evidenced |
| FR-12 | Refresh and states | AC-20 | Evidenced except the pull-down gesture itself |
| FR-13 | Badge | AC-17 | Evidenced; "99+" is a client format, only the number is tested on the server |
| FR-14 | Order detail | AC-24 | Evidenced |
| FR-15 | Call and Zalo | AC-25 | **Manual only** (device) |
| FR-16 | Confirm | AC-26 | Evidenced |
| FR-17 | Complete | AC-27 | Evidenced |
| FR-18 | Cancel with reason | AC-28 | Evidenced |
| FR-19 | Stale view and repeats | AC-29 (and AC-22 for D-1) | Evidenced |
| FR-20 | Settings, five entries, owner only | AC-8, 48 | Evidenced |
| FR-21 | Cakes | AC-32, 33, 34 | Evidenced; HEIC on Android 8/9 and real photo library not run |
| FR-22 | Ordering rules | AC-35, 36 | Evidenced |
| FR-23 | Districts and slots | AC-37, 38 | Evidenced |
| FR-24 | Shop info | AC-39 | Evidenced |
| FR-25 | New-order push | AC-42, 44 | Evidenced with the fake sender only (D-2) |
| FR-26 | Push content and tap | AC-43, 31 | Payload evidenced; tap on a real notification manual |
| FR-27 | Cancelled orders and the phone limit | AC-46 | Evidenced (BE and QA) |

## ACs with no automated evidence (or only partial)

| Item | AC / FR | What is missing | Handling |
| ---- | ------- | --------------- | -------- |
| G-1 | AC-13, FR-8 | Fixed-code review sign-in and the 3 demo orders: code does not exist (`REVIEW_ACCOUNT_*` is in deployment/04 but not in `backend/Sources`). Only the visibility and capacity rules of demo rows are tested | Defect D-1, forge-dev, or owner decision to defer |
| G-2 | AC-25, FR-15 | Dialer and Zalo launch on a device (unit test checks URL building only) | Manual on one iPhone and one Android phone |
| G-3 | AC-42, 43, 44, FR-25, FR-26 | Real APNs and FCM delivery, 60 s, token on a real device, tap on a delivered notification. `ApnsPushSender` and `FcmPushSender` never ran against Apple or Google; Android has no FCM service in the build (`src/pushFcm` absent) | Defect D-2; two real devices before go-live (DP-Q4) |
| G-4 | AC-12, FR-7 | Real e-mail delivery; owner-visible notice text on a real mailbox | Manual with a real provider (not approved, free tier) |
| G-5 | AC-5 | A phone idle for 6 d 23 h and 7 d on a real device: Keychain and Android Keystore storage of the refresh token and behaviour after reinstall | Clock tests on the server; client storage is code review only |
| G-6 | AC-8 | Android: staff never sees the Settings tab (code: `OrdersHome.kt`; no instrumented test for the staff role) | Add an Android test (forge-dev, low) |
| G-7 | AC-17 | The text "99+" on the badge, hidden at 0, on both apps (server returns the number) | Manual or add a UI test |
| G-8 | AC-20 | Pull-down refresh gesture | Manual |
| G-9 | AC-30, 31 | Tap counts (goal checks) | Manual count; one run recorded in part 12 only for flows the UI tests drive |
| G-10 | AC-33, FR-21 | HEIC and large camera photos on Android 8 and 9 (minSdk 26), photo picker differences; iOS photo library permission flow | Real devices or emulators API 26 and 28 (not run) |
| G-11 | AC-44, 45 | App preview cover when going to the background (iOS `RootView`, Android `FLAG_SECURE`), no customer data after sign-out on the device, crash report content | Manual with the app switcher; no automated check |
| G-12 | NFR | VoiceOver and TalkBack, Dynamic Type and font scale, dark mode on the admin screens, iOS 17.5 simulator (UI suite ran on the orchestrator's simulator only) | Manual accessibility pass |
| G-13 | NFR | Load beyond one host (single database, no concurrency above 8 parallel callers) | Indicative only (part 11) |

## Coverage of the removed (deferred) features

Absence is tested: `view=unfinished`, `date_from`, `date_to`, repeated `status` answer 422 `UNKNOWN_PARAMETER` or `REPEATED_PARAMETER` (QA AdminSearchCursorTests::TCB57); `DELETE /v1/admin/push-token` answers 404 (QA AdminPushTests::TCB93, BE PushRegistrationTests::ThereIsNoDeleteRoute); no order edit or delete route exists (BE RoleCoverageTests::NoOrderEditOrDeleteRouteExists); `day_full` is refused as a reason (QA AdminStatusRulesTests::TCB78). Recovery, device list and backup e-mail routes: none in the router (the sweeps in QA AdminRoleMatrixTests list only the routes of the build). [v2.0 | 2026-11-01]
