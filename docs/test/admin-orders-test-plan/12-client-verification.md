# Admin Orders Test Plan: Client verification evidence, iOS and Android (part 12)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v2.0). Holds: what the client suites cover and do not cover on commit 6852302. probe-qa did not run the heavy client suites; the counts are the orchestrator's runs, and the test names were read from the repository. The TC-C cases of [part 06](06-cases-clients-contracts.md) are answered here by named tests (matrix: [part 02](02-traceability-matrix.md)). [v2.0 | 2026-11-01]

## 12.1 Runs reported by the orchestrator (not re-run by probe-qa)

| Suite | Count | Result reported | Nature |
| ----- | ----- | --------------- | ------ |
| iOS `BanhAdminTests` | 93 | pass | Swift Testing: view models, session manager, API clients with a scripted transport, fixtures, support code |
| iOS `BanhAdminUITests` | 55 | pass | XCUITest on a simulator against a stub backend (scripted answers) |
| iOS `BanhCore` (package) | 9 | pass | Shared core |
| iOS `BanhApp` (customer app, regression) | 201 | pass | Place Order app, unaffected code; regression of the shared package |
| Android `:admin` unit | 117 | pass | JVM tests: reducers, session manager, HTTP clients with a fake engine, validation, image fitting |
| Android `:admin` instrumented | 64 | pass | Compose tests on an emulator with fake APIs (8 of them are screenshot tours, `OwnerShotsTest` 5 and `ScreenshotTourTest` 3, which assert little) |
| Android `:app` (customer app, regression) | 184 | pass | Place Order app |

Contract fixtures: both apps decode the shared admin fixtures (iOS `ContractFixtureTests`, `OwnerFixtureTests`; Android `OwnerFailureTest::theOwnerFixturesDecodeIntoTheModels`, `HttpOrdersApiTest`, `HttpOwnerApiTest`), and the backend compares its real answers with the same files (BE `AdminFixtureTests`, `OrderFixtureTests`, `OwnerSettingsFixtureTests`, `OwnerCakeFixtureTests`). The fixtures are the only link between the client suites and the server tests. [v2.0 | 2026-11-01]

## 12.2 What the client evidence covers (per area)

| Area (TC-C range) | iOS | Android |
| ----------------- | --- | ------- |
| Sign-in, code step, resend wait, rate-limit text, revoked session banner (C01 to C04, C46, C49) | iU SignInViewModelTests (7), iUI SignInUITests (7) | aU SignInReducerTest (8), aI SignInFlowTest (5) |
| Token handling: refresh once and retry, shared refresh, grace retry, revoked, offline sign-out (C04, C05, C49) | iU SessionManagerTests (10) | aU SessionManagerTest (13) |
| Order list: To do default, chips, date menu, search from 3 characters and cut at 50, paging, due marks, badge, empty/offline/error (C07 to C16) | iU OrderListViewModelTests (9), iUI OrdersUITests (9) | aU OrderListReducerTest (8), aI OrderFlowTest (8) |
| Order detail and actions: Confirm one tap, Complete with dialog, Cancel with reason, conflict, gone (C17 to C23) | iU OrderDetailViewModelTests (6), iUI StatusUITests (6) | aU OrderDetailReducerTest (8), OrderDetailViewModelTest (4) |
| Settings: five rows, rules with the lower-limit warning, shop info (C26 to C29) | iU OwnerSettingsViewModelTests (9), iUI OwnerSettingsUITests (8) | aU RulesTest (8), ShopTest (5), aI SettingsFlowTest (3), RulesShopFlowTest (7) |
| Cakes: add with picture, 12 limit, last active, remove, upload cancel (C34 to C36) | iU CakeFormViewModelTests (14), SupportTests (photo, 5), iUI CakesUITests (10) | aU CakeFormTest (14), ImageFitTest (8), aI CakeFlowTest (11), PhotoEncoderTest (6) |
| Delivery and staff (C30 to C33) | iU OwnerStaffViewModelTests (5), iUI DeliveryStaffUITests (9) | aU DeliveryTest (7), StaffTest (5), aI DeliveryStaffFlowTest (8) |
| Push: permission asked once, token registered after sign-in, forgotten at sign-out, toast in the foreground, tap opens order, tap while signed out, unknown order (C31, C39, C40, C43) | iU PushAndOwnerAPITests (9), iUI PushUITests (4) | aU PushTest (7), aI PushFlowTest (8) |
| Account: sign out, sign out other phones, own e-mail shown (C06, C25) | iUI AccountUITests (2) | aI SettingsFlowTest::accountEmailIsAlwaysShown |

The client tests pin the server contract names (`STATUS_TRANSITION_INVALID`, `ORDER_STATE_CHANGED`, `CANCEL_REASON_REQUIRED`, `LAST_ACTIVE_*`, `CAKE_LIMIT_REACHED`, `NAME_TAKEN`, `IMAGE_*`), the 3-character search rule, the 50-character cut, and the server-date rule for "due today" and the date picker (the device clock is not used). [v2.0 | 2026-11-01]

## 12.3 What is NOT covered (all remain Blocked or manual)

| Item | Why | Risk |
| ---- | --- | ---- |
| Real stack end to end (an admin app against the real backend over HTTP) | UI suites use a stub backend; backend suites use no app. Only shared fixtures link them | Medium: a mismatch not captured by the fixtures (header names, multipart field names, date formats on the wire) would only appear on a device. Conditional go: one manual smoke run (sign in, list, confirm, cancel, add a cake with a picture) against a local backend |
| iOS Keychain and Android Keystore storage | Unit tests use fake stores; `freshInstallClearsLeftoverKeychainItems` is a fake | Low to medium: first real-device run decides |
| Real push (APNs, FCM), permission dialog on a device, background delivery, notification tap from the lock screen | No credentials; Android build has push off by design (`src/pushOff`); iOS needs Apple Developer Program | High for go-live, none for the pull request: defect D-2 |
| VoiceOver, TalkBack, Dynamic Type, font scale, dark mode, landscape (iPhone only) | No accessibility run was done | Medium for G-1 (every kind of user); manual pass needed |
| iOS 17.5 simulator (minimum is iOS 17.0) | UI suite ran on the orchestrator's single simulator runtime | Low |
| HEIC and large photos on Android 8 and 9 (minSdk 26); iOS photo permission flow | Emulator API level of the instrumented run not recorded; picker differs per version | Medium for the cake picture feature on old phones |
| App preview cover (iOS) and `FLAG_SECURE` (Android) when the app goes to the background | Present in code (`RootView.swift`, `SecureWindow.kt`), no test | Low to medium (AC-45) |
| Dialer and Zalo launch | Device feature (AC-25) | Low |
| Pull-down gesture, "99+" text, 2-tap and 1-tap goal counts | Not asserted by any test found | Low |
| Staff role hides Settings on Android | Code only (`OrdersHome.kt`) | Low (server refuses anyway, AC-8 evidence QA TCB22) |
| Offline/slow network behaviour with a real radio, background refresh, process death during an upload | Only simulated through fakes | Low |

[v2.0 | 2026-11-01]
