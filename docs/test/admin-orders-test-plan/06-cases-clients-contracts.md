# Admin Orders Test Plan: iOS and Android cases, contract fixtures (part 06)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: TC-C01 to TC-C47 (each runs on iOS and on Android; results kept per platform) and TC-F01 to TC-F07. UI wording is Vietnamese; exact texts come from the (not yet written) admin UI spec. States are taken from FR-13 and the PRD. Every result is `Not run` for iOS / Android. [v1.0 | 2026-10-31]

## 4.14 Client cases (both platforms)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-C01 | acceptance | AC-1, 2, 3, 7 | Sign-in: registered and unregistered address, then code; "change e-mail" | Same code step for both addresses; right code opens the list; address kept when going back |
| TC-C02 | acceptance | AC-6 | Resend control at 10 s and 30 s | Disabled with seconds left, enabled at 30 s; new code replaces old |
| TC-C03 | negative | AC-4, 5, 8, 9 | Expired, reused, 6th-attempt and 4th-request cases | Vietnamese message with the wait; no session; fields cleared sensibly |
| TC-C04 | acceptance | AC-10, 11 | Relaunch at day 6 and day 8; sign out | Day 6 list; day 8 sign-in; after sign-out the sign-in screen and an old back-navigation shows nothing |
| TC-C05 | acceptance | AC-14, 55 | Account deactivated / device revoked while the app is open | Within 5 min the next request ends in the sign-in screen; other device continues |
| TC-C06 | negative | AC-54 | Replay of an old renewal credential (stub) | App shows sign-in, stored data cleared |
| TC-C07 | acceptance | AC-15, 16 | Default list with the seed of TC-B53 | Order D, B, A; each row shows all required fields; dong with dot separators |
| TC-C08 | acceptance | AC-17, 18 | Status chips; today, tomorrow, one date, range | Results match; selected filters visible; status shown with a word |
| TC-C09 | acceptance | AC-19 | Search `AAAAAA`, `Thi B`, `0900000010`, `zzz` | Found / empty state |
| TC-C10 | acceptance | AC-20, 21 | New count badge, pull-to-refresh, "last updated" time | Count 3 to 4 after refresh; time of last successful update shown; not updated on failure |
| TC-C11 | acceptance | AC-22 | Empty result; airplane mode; server 500 (stub) | Empty text; offline text + retry, no old data shown as current; error + retry; loading state shown |
| TC-C12 | acceptance | AC-23 | 120 orders, scroll to end twice | 50, 100, 120 rows; no duplicate row; end of list stops requesting |
| TC-C13 | acceptance | AC-24, 25 | Detail; call; Zalo (installed and not installed) | All FR-14 fields; dialer opens with number (real device); Zalo not installed shows Vietnamese message |
| TC-C14 | acceptance | AC-26, 27 | Confirm; complete a Confirmed order due in 5 days | Status updates in detail and list; no further action; New order offers no complete |
| TC-C15 | acceptance | AC-28, 29, 69 | Cancel: open step, back, reason list, confirm | Confirmation names the code; exactly five reasons; confirm disabled until a reason is chosen; back keeps status; steps from tap to cancelled counted (G-2) |
| TC-C16 | acceptance | AC-30 | Stale view (stub returns conflict) | Current status shown with Vietnamese message; no action offered on final states |
| TC-C17 | acceptance | AC-31 | History panel | Oldest first, old/new status, name, date and time, reason on cancel |
| TC-C18 | acceptance | AC-32 | Sign in as staff, then as owner | Staff: orders only, no settings or staff entry; owner: both |
| TC-C19 | acceptance | AC-33, 34 | Edit price, hide a cake, hide the last active cake | Saved values shown; last-active message in Vietnamese |
| TC-C20 | negative | AC-36, 40, 41, 45 | Invalid forms (price 0, empty name, 301-char greeting, bad slot, bad phone, last district) | Message names the field; nothing saved; form keeps input |
| TC-C21 | acceptance | AC-38 | Lower the limit below accepted dates | Warning lists dates and cake counts before save; save and cancel both work |
| TC-C22 | acceptance | AC-42, 43, 44 | Add, duplicate, 31st, deactivate, reactivate staff | Messages and list update; owner has no deactivate control |
| TC-C23 | acceptance | AC-48, 50 | Push to simulator/emulator (payload injection); tap while signed in, signed out, app killed | Detail of that order opens in at most 2 taps from the notification; after sign-in when needed. Real APNs/FCM Blocked |
| TC-C24 | acceptance | AC-49, 51 | Notification text; permission denied | Text has code, cakes, date only; app fully usable; hint shown once per sign-in |
| TC-C25 | acceptance | AC-52 | Sign out; inspect app storage, cache, logs, snapshots | No customer name, phone or address remains on the device |
| TC-C26 | acceptance | AC-56 | Devices screen as staff and as owner | Staff: own only; owner: all with account, device name, last used; revoke asks confirmation |
| TC-C27 | acceptance | AC-57, 58, 59 | Backup e-mail set; recovery with two codes; one wrong; no backup | Flow works; reminder to set backup shown until set (BR-17); recovery hidden without backup |
| TC-C28 | acceptance | AC-60, 61, 62, 63 | Add cake with JPEG, PNG, HEIC from the photo picker, GIF, 6 MB; remove a cake | HEIC is converted or refused with a message (R-16); 13th cake message; removal confirmation names the cake; removed cake gone from settings |
| TC-C29 | acceptance | AC-64, 65 | Customer-side texts after rule changes | Customer app (iOS and Android) shows the current lead days and minimum; cart with old minimum is told and can adjust |
| TC-C30 | acceptance | AC-67, 68 | Open an order 91 days old by notification or stored link | "Not found" state; no data |

## 4.15 Extra client cases

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-C31 | extra | FR-19 | Confirm tapped twice fast; tap during a slow response | One request; button disabled while pending |
| TC-C32 | extra | NFR a11y | Largest system font; screen reader; contrast of status colours | Text scales without clipping; every control labelled; status has a word; 4.5:1 |
| TC-C33 | extra | FR-12 | App to background for 10 min then foreground | List refreshes on open; time shown updates |
| TC-C34 | extra | FR-19 | Two devices act on the same order (stub or real server) | Loser sees the conflict message and the fresh status |
| TC-C35 | extra | FR-13 | Network lost during status change | Error with retry; after retry exactly one history entry; no false success |
| TC-C36 | extra | AC-50 | Notification tap for an order that was cancelled meanwhile | Detail shows Cancelled with reason, no action |
| TC-C37 | extra | BR-5 | Android back / iOS swipe-back and process kill during code entry; paste/auto-fill of code | Entry state is restored or restarts cleanly; code from clipboard accepted |
| TC-C38 | extra | AC-50 | Tap a notification while signed out as another account | Sign-in first; the detail opens only if that account may see it; no data of the previous account |
| TC-C39 | extra | NFR | Money and dates | `dd/MM/yyyy`, `1.234.000`; same on both platforms |
| TC-C40 | extra | FR-4 | Rotate/locale change, dark mode, phone language not Vietnamese | Vietnamese text; layout intact |
| TC-C41 | extra | FR-31 | Second user signs in on the same phone after sign-out | Previous user's list not visible; push goes to the new user only |
| TC-C42 | extra | BR-15 | App switcher / recent apps screenshot while a detail is open | Customer data hidden in the snapshot, or recorded as a gap (R-19) |
| TC-C43 | regression | PRD section 9 | Customer app (both) with a catalog of 12 cakes and long names, owner images, and with 1 cake | List scrolls, images load, placeholders for slow image; ordering works; no layout break |
| TC-C44 | extra | FR-34 | Permission denied, then granted in system settings | Push registers without re-signing in; hint stops |
| TC-C45 | extra | A-1 | Device clock and time zone set to another country | "Today" filter uses server shop date |
| TC-C46 | extra | FR-1 | E-mail keyboard; autocorrect/capitalisation; trailing space; paste | Address trimmed; no auto-capitalised first letter problem; case-insensitive |
| TC-C47 | extra | FR-37 | Owner revokes the device it is on | App signs out cleanly and returns to sign-in |

## 4.16 Contract fixtures (to be created as `contracts/fixtures/admin-*.json`)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-F01 | acceptance | AC-22 | Backend golden test for each admin response (sign-in, refresh, list page, detail, devices, settings, cake, errors incl. conflict, forbidden, rate limited, validation with field name) | Server output equals the fixture shape; error codes come from the shared enum |
| TC-F02 | acceptance | FR-8..20 | iOS `BanhContracts` decodes every `admin-*` fixture | All decode; unknown fields tolerated |
| TC-F03 | acceptance | FR-8..20 | Android decodes the same fixtures | Same as TC-F02; same displayed values |
| TC-F04 | negative | contract | Fixtures with missing optional fields (no note, no reason, no backup) and unknown status value | Clients show a safe state; unknown status never crashes |
| TC-F05 | extra | public repo | Scan fixtures for real e-mails, phones, tokens, hostnames | Only `example.com`, `+84 900 000 0xx`, placeholder tokens |
| TC-F06 | acceptance | AC-49, FR-32 | Push payload fixture | Keys: code, cake count, delivery date, order id; no name, phone, address, note |
| TC-F07 | extra | FR-44 | Place-order fixtures `order-error-rate-limited`, `catalog-ok` (extended to 12 cakes, image URLs) still decode on both customer apps | No regression of customer contracts |
