# System Architecture: Admin apps part 1 alignment, shared code as built, session handling, own e-mail on `me`

Part of [architecture.md](../architecture.md) (index, version, change log), section 31. New in v1.19 [v1.19 | 2026-11-01]. The iOS and Android admin apps (part 1: sign-in, orders, account) are built; the system documents now follow the code. Sources read: `ios/BanhAdmin/` (`Core/Auth`, `Core/Models`, `App/AppCoordinator`), `ios/Packages/*`, `android/admin/` (`auth/`, `AdminContainer`, manifest), `android/core/*`, `android/build-logic`, `android/settings.gradle.kts`, `ImportDirectionTest`, `backend/Sources/App/Routes/Admin/{AdminRoutes,AuthDTOs}.swift`, dev guide paragraphs of v1.15 and v1.16. Format as in [14-b7-alignment.md](14-b7-alignment.md).

## 31.1 Decisions and corrections

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| Own e-mail on `me` | `GET /v1/admin/me` returns `{ account, email, device_id, server_date }`. `email` is the caller's own address only, never logged, `no-store` (every admin response already is), kept in memory by the apps and never written to disk. Reason: after a launch with a stored session the sign-in answer is gone and S-A13 would show no address | api/06 10.6, api/05 index, api v1.22, auth v2.6 |
| ADR-0021 as built | Android: `:core:design` extracted (customer design package moved there, customer app imports it), `:core:model`, `:core:network`, `:core:common`, `build-logic` with `banh.android.library` and `banh.android.compose`, `:admin` is the admin app; customer data and order code stay in `:app`; `ImportDirectionTest` only forbids a `design` package in `:app`; the Compose compiler spike worked (AGP 9.4, Kotlin 2.4.21). iOS: `ios/BanhAdmin.xcodeproj` (format 77, synchronized folders), local packages `BanhCore` and `BanhDesign` | ADR-0021 v1.1, architecture/06 section 15.1, architecture/07 R-AO-6 |
| ADR text not met | `BanhCore` has no repository protocols; admin Codable types are in `BanhAdmin/Core/Models`, not in `BanhContracts` (Android has them in `:core:model`) | ADR-0021 v1.1 |
| Storage | iOS Keychain (`AfterFirstUnlockThisDeviceOnly`); Android AES-256-GCM key in the Keystore, file in `noBackupFilesDir`, `allowBackup="false"`, atomic write, unreadable file means signed out | ADR-0022 v1.5 |
| 7-day limit of the pending sign-out | Built in neither app (Android has no timestamp either). Not needed: after 7 days without refresh the retry's refresh answers 401 `SESSION_EXPIRED`, both apps then drop the pending token, and the server session is already dead. Docs now say the server enforces it | session-lifecycle v1.5, ADR-0022 v1.5 |

## 31.2 Known duplication: customer iOS app and the packages

The customer iOS app does NOT use `ios/Packages`. Its `Core/Design` and `Core/Network` stay as they are, and the admin packages hold a copy of design and network code; moving the customer app would touch every customer file and put its release at risk (ADR-0021 driver 1). Cost: a change to tokens, components or the error envelope must be made twice. Condition to remove it: a customer iOS change that already edits most files, or the first bug fixed in both copies. Then, as its own change: customer imports `BanhDesign` and `BanhCore`, the old folders are deleted, customer unit and UI tests and the import-direction script stay green. Android has no such duplication.

## 31.3 Session handling, documents against code

| Rule (ADR-0022, ADR-0024, api/05, api/08) | iOS | Android |
| ----------------------------------------- | --- | ------- |
| Refresh token in platform store | Keychain, this device only: matches | Keystore AES-GCM file in `noBackupFilesDir`: matches |
| 401: refresh once, retry once, else sign-in | Matches; any 401 other than `SESSION_REVOKED` or `SESSION_EXPIRED` refreshes | Differs: only `ACCESS_TOKEN_EXPIRED` refreshes, `UNAUTHENTICATED` ends the session at once (D-2) |
| Single flight | Actor with one shared task: matches. A caller with a stale token starts a second rotation after the first (harmless, D-6) | Mutex plus stale-token check: matches |
| Lost refresh response keeps the old token (20 s) | Matches | Matches |
| Offline sign-out: clear at once, pending flag, retry at launch | Matches (pending token in its own Keychain item) | Matches (flag in the stored session) |
| Pending retry stops on 401, keeps on network or server trouble | Differs: a 429 or 5xx also clears it (D-3) | Matches |
| Own e-mail after launch | Not shown: `me` had no `email` (D-1) | Same (`email = null` in `restore`) |
| New sign-in replaces the old session of the installation | Server side; a pending token of the previous session may stay unused until launch and ends by 401 | Overwrites the vault; the server already revoked that session |
| Reinstall | Keychain outlives the app, `UserDefaults` does not (D-4) | `noBackupFilesDir` is removed with the app: matches |

## 31.4 Open defects for forge-dev

| ID | Defect | Severity |
| -- | ------ | -------- |
| D-1 | Backend `MeResponse` (`AuthDTOs.swift`) and `AdminRoutes.me` do not return `email` yet; add it from the account of the principal, plus a test that the logs and a `no-store` header stay clean. Then `contracts/fixtures/admin/me.json` and its row in `contracts/fixtures/README.md` (not Atlas paths), iOS `MeResponse` and `AppCoordinator.start` (`email: nil`), Android `AuthModels` `Me` and `SessionManager.restore` (`email = null`) use it; the iOS comment "does not return it" goes | Medium |
| D-2 | Android `SessionManager.authorized` ends the session on any 401 except `ACCESS_TOKEN_EXPIRED`; api/08 says `UNAUTHENTICATED` tries one refresh. Align (refresh once, then fail) | Low |
| D-3 | iOS `completePendingSignOut` clears the pending token on `.service` and `.invalidResponse` (429, 5xx) for both the refresh and the `DELETE`; only a 401 or a 2xx should clear it, as Android does. A server hiccup at launch otherwise leaves a live session and its push token | Medium |
| D-4 | iOS Keychain items survive deleting the app; after a reinstall the app starts with the old refresh token and a new installation id. Clear both Keychain items when the `UserDefaults` installation id is missing at first start | Low |
| D-5 | iOS: no code and no test for the 7-day limit; accepted (31.1). Add a test that a 401 `SESSION_EXPIRED` on the pending refresh clears the token | Info |
| D-6 | iOS `authorized` refreshes again when a second caller returns with an already replaced token (Android compares with the stale token). Harmless, one extra rotation | Info |

Queries for other agents: none. canvas-ui documents untouched.
