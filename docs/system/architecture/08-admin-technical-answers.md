# System Architecture: Admin technical answers (UI questions and QA review items)

Part of [architecture.md](../architecture.md) (index, version, change log), section 24. Ids in lines touched in v1.13 follow PRD v1.6 [v1.13 | 2026-10-31]. New in v1.11 [v1.11 | 2026-10-31]; R-7 and TQ-12/13 pointer in v1.12 [v1.12 | 2026-10-31]. Answers the technical questions TQ-D1 to TQ-D7 of `design/admin-orders/11-traceability-questions-changelog.md` and the review items owned by the architect in `test/admin-orders-test-plan/08-review-findings.md`. Where an answer changes a contract, the contract file is named; this file adds no endpoint.

## 24.1 Answers to the UI questions

| ID | Answer | Where it is written |
| -- | ------ | ------------------- |
| TQ-D1 | The app always decodes the picked picture and re-encodes it as JPEG (longest side 1600 px, quality 80), so HEIC never reaches the server. Upload is ONE multipart request, atomic on the server; no two-step upload. Failure to decode: the unsupported-picture message | ADR-0025 v1.1; api/07 10.17 |
| TQ-D2 | Android uses the stable Material 3 `NavigationBar`. Experimental Material 3 Expressive components may be adopted later only behind the wrapper components of ADR-0007 and only when they are stable in the pinned library version; no change to behaviour or contracts | ADR-0007 (R-7 of architecture/05) |
| TQ-D3 | Android channel `new_orders` importance HIGH (sound, heads-up, vibration), priority high, expiry 1 hour. iOS alert push, priority 10, expiry 1 hour, interruption level `active` (not `time-sensitive`), grouped by `thread-id`. Rationale: a new order should be noticed in the shop; a night bypass of Focus is not wanted and the list is the truth | ADR-0024 v1.1; api/06 10.12 |
| TQ-D4 | See 24.2 | This file; deployment/04 section 13 |
| TQ-D5 | A preview endpoint (already `GET /v1/owner/settings/ordering/impact`), no confirmation token. The save always succeeds and its response repeats `over_limit` computed at save time, so a race shows the true list afterwards. Cancelling nothing is BR-11 | api/07 10.15 |
| TQ-D6 | App clears data and shows sign-in at once; it keeps only a pending sign-out (refresh token, no customer data), unregisters the push token locally, repeats refresh then `DELETE /v1/admin/session` until 204 or 401, at most 7 days. The person can use "Sign out all other phones" from another phone | ADR-0022 v1.3; api/06 10.6; session-lifecycle.md |
| TQ-D7 | The API supports partial name, phone and code search from 2 characters (substring, diacritics and case ignored). The apps may require 3 characters; that is a UI choice. At about 9,000 rows a scan takes milliseconds | ADR-0029 v1.1; api/06 10.9 |

## 24.2 App-switcher and capture privacy (TQ-D4, R-19)

| Platform | Rule |
| -------- | ---- |
| iOS | When the scene becomes inactive or goes to the background, a full-screen opaque brand view covers the content before the system takes its snapshot; removed when active again. Screenshots cannot be blocked on iOS (accepted: staff are trusted, BR-7 concerns storage and display) |
| Android | `FLAG_SECURE` on the window while an order list, order detail or search screen is shown (blocks the recents thumbnail and screenshots there); on Android 13 and later also `setRecentsScreenshotEnabled(false)` for the whole app. Settings screens may be captured |
| Backups | Android `allowBackup="false"` and data-extraction rules excluding everything (the app-private store holds only the Keystore-wrapped credentials and cached lists, cleared at sign-out); iOS Keychain items `ThisDeviceOnly`, no customer data in files; no iCloud document storage |
| Logs and analytics | No analytics SDK exists in either app; logs hold no customer data (api/05 section 9); crash reports, if added later, need a new ADR (R-34) |

Residual risk: a person photographing the screen, or screenshots on iOS. Not reducible by the app.

## 24.3 Review items owned by the architect

| ID | Answer | Written in |
| -- | ------ | ---------- |
| R-6 | Limits per client address now cover every `/v1/auth` route (20 code requests an hour, 60 an hour for the others) and 401 answers on admin and owner routes (60 a minute). Mail flooding of third parties is bounded by design: mail goes only to registered active addresses (at most 31), 3 an hour each, plus the daily cap. The client address is unreliable behind the proxy (ADR-0019 open), so these limits are an extra; the address and global keys do the work | auth/abuse-secrets-threats.md 4.2; api/05 section 9; deployment/04 |
| R-7 | Superseded by PRD v1.4 (Q-20, BR-4) [v1.12 \| 2026-10-31], recovery removed [v1.13 | 2026-10-31]: no address lock; the 5th wrong entry voids the code (counted on `auth_code.wrong_count`); only the daily mail cap is global | auth/abuse-secrets-threats.md 4.2; ADR-0022 v1.2 |
| R-10 | The per-phone limit ignores cancelled orders except `fake_spam` (BR-8, FR-27) in auth, api/01, ADR-0014 and data-model. `auth.md` v2.0 already removed phone and SMS sign-in; the "later slice" wording of staff features is removed from order-lifecycle.md v1.6 and data-model/02 | order-lifecycle.md; api/01; ADR-0014 |
| R-12 | A grace window of 20 s (`REFRESH_GRACE_SECONDS`): a retry with the previous refresh token inside it returns a new pair; later reuse revokes the session. Accepted by the owner | ADR-0022 v1.1; api/05 10.3 |
| R-14 | Keyset paging on keys that never change: no repeat; new and status-changed orders appear on the next refresh from page 1; a row can leave the filter before it is fetched. Not a snapshot | ADR-0029 v1.1; api/06 10.9 |
| R-16 | Body limit is per route: 8 KB everywhere, 5,308,416 bytes (file 5,242,880 plus 65,536) on `POST /v1/owner/cakes` only. "5 MB" is 5,242,880 bytes; exact size passes, one byte more is `IMAGE_TOO_LARGE`. HEIC is converted on the device. Auth runs before the body is read; at most 2 uploads in flight | ADR-0025 v1.1; api/05 section 9; api/01 section 1 |
| R-17 | Last write wins for settings (one owner, rare); no version check; every change is in `settings_change` with old and new value; the app reloads after a refusal. Reversible later by adding a revision field | api/07 10.15 |
| R-22 | Definitions for tests: see 24.4 | This file |
| R-23 | Server preview, advisory; the save is authoritative and returns the list at save time | api/07 10.15 |
| R-29 | `device_name` = model and system version built by the app, never a user-assigned name; 1 to 60 characters | api/05 10.2 |
| R-30 | Same as TQ-D6; until the pending sign-out reaches the server, pushes (code, cakes, date only) can still arrive; the local push token is unregistered at once | ADR-0022 v1.1 |

## 24.4 Measurable service targets (R-22)

"Normal network conditions" cannot be tested; the targets below are measured on the server with recording senders and a test clock, so they are automatable. The last mile (provider, carrier, phone) is checked once by hand on real devices before go-live.

| Requirement | Test definition | Manual check |
| ----------- | --------------- | ------------ |
| New order push within 60 s | From the commit of the order to the first call of the push sender: at most 5 s at p95 (recording sender timestamp), with retries after 1, 5 and 20 s counted | Two real devices; needs the Apple Developer Program, not yet approved (DP-Q4), so the iOS check waits |
| Code mail within 60 s | From the 202 answer to the first call of the mail sender: at most 5 s; one retry after 5 s | One mailbox at two providers after the domain exists (blocked, DP-Q4) |
| Revocation or deactivation within 5 minutes | Design gives 0 s: the next request with an unexpired access token answers 401. Test: revoke, then call at once. The 5 minutes is only the access token life if a check were ever cached | None |
| Order list first page | At most 500 ms at p95 on a warm database with 9,000 seeded orders in the window (ADR-0029); cold start excluded | None |
| Sign-in valid for 7 days | Boundaries from the PRD v1.3 rules; test with an injected clock | None |

Open boundary rules (R-5: minute 10:00 of a code, exactly 90 days) are for the requirements agent; until stated, the build uses "valid while `now < expires_at`" for codes and sessions, and `created_at >= now() - 90 days` for the window (ADR-0029).
