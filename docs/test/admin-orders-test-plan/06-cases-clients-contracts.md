# Admin Orders Test Plan: iOS and Android cases, contract fixtures (part 06)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: TC-C01 to TC-C51 (each runs on iOS and on Android; results kept per platform) and TC-F01 to TC-F08. Vietnamese texts come from the UI spec; it is still on PRD v1.2, so expected texts below name the behaviour and the exact strings are checked after design updates it (R-30 to R-34). Every result is `Not run` for iOS / Android. [v1.1 | 2026-10-31]

## 4.16 Client cases (both platforms)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-C01 | acceptance | AC-1, 2, 3 | Registered and unregistered address, then code; "change e-mail" | Same code step for both; right code opens the list; address kept when going back; owner sees no second step [v1.1 | 2026-10-31] |
| TC-C02 | acceptance | AC-3 | Resend control at 10 s and 30 s | Disabled with seconds left; enabled at 30 s; new code replaces old [v1.1 | 2026-10-31] |
| TC-C03 | negative | AC-2, 4 | Expired, reused, 5 wrong entries, 4th request | Vietnamese message: expired/void says "request a new code" and no minute wait; 4th request shows the wait; no lock screen exists; fields cleared sensibly [v1.1 | 2026-10-31] |
| TC-C04 | acceptance | AC-5 | Relaunch after 6 d 23 h 59 min and after 7 d | First: list without code; second: sign-in screen [v1.1 | 2026-10-31] |
| TC-C05 | acceptance | AC-6 | Sign out; back navigation | Sign-in screen; nothing of the old data reachable [v1.1 | 2026-10-31] |
| TC-C06 | acceptance | AC-7 | Two phones; "Sign out all other phones" on phone 1 as staff and as owner | Button visible to both roles; this phone keeps working; phone 2 shows sign-in within 5 min of use; no device list or per-phone control anywhere [v1.1 | 2026-10-31] |
| TC-C07 | acceptance | AC-8, 48 | Sign in as staff, then owner | Staff: orders and account only, no Settings or Staff entry; owner: Settings [v1.1 | 2026-10-31] |
| TC-C08 | acceptance | AC-9, 10 | Add staff; duplicate; bad address; 31st; switch off and on | Messages and list update; owner row has no switch-off control [v1.1 | 2026-10-31] |
| TC-C09 | negative | AC-11 | Stub replays an old renewal credential | App shows sign-in; stored data cleared [v1.1 | 2026-10-31] |
| TC-C10 | acceptance | AC-13 | Sign in as review account (stub or test backend) | Exactly 3 demo orders; no real data [v1.1 | 2026-10-31] |
| TC-C11 | acceptance | AC-14, 15 | Default "To do" list with the seed of TC-B49 | Order D, B, A; each row shows required fields, no phone/address/note; dong with dot separators [v1.1 | 2026-10-31] |
| TC-C12 | acceptance | AC-16 | Seed of TC-B52 | A red "overdue 2 days", B red "due today", C no mark; All adds D, E without marks; mark is text, not colour alone [v1.1 | 2026-10-31] |
| TC-C13 | acceptance | AC-17 | Badge with 3, 0, 120 overdue; complete one order in detail and return | Red "3"; hidden at 0; "99+" at 120; number drops without reopening the app or pulling [v1.1 | 2026-10-31] |
| TC-C14 | acceptance | AC-18 | Status choice (one at a time, six values) and date choice (any, today, tomorrow, one date) | Results match; chosen filters visible with a word; no multi-select, no Unfinished chip, no banner [v1.1 | 2026-10-31] |
| TC-C15 | acceptance | AC-19 | Search `aaaaaa`, `tran thi`, `0900000010`, `zzz`, `ab` | Found / empty state / "3 characters" hint with no request for `ab` [v1.1 | 2026-10-31] |
| TC-C16 | acceptance | AC-20 | Pull to refresh; empty; airplane mode; server 500 (stub); loading | New order appears; Vietnamese empty, offline and error texts with retry; old data not shown as current [v1.1 | 2026-10-31] |
| TC-C17 | acceptance | AC-22 | Old overdue order (placed 100 days ago): open, cancel with a reason, refresh | Row marked overdue 75 days; opens; after cancel it leaves the list; reopening gives not found [v1.1 | 2026-10-31] |
| TC-C18 | acceptance | AC-21 | Open a 91-day order by notification or stored link | "Not found" state; no data [v1.1 | 2026-10-31] |
| TC-C19 | acceptance | AC-23 | 120 orders, scroll to the end twice | 50, 100, 120 rows; no duplicate; stops at the end [v1.1 | 2026-10-31] |
| TC-C20 | acceptance | AC-24, 25 | Detail; Call; Zalo installed and not installed | All FR-14 fields incl. "last changed by"; cancel reason on cancelled; no history panel; dialer opens (real device); Zalo missing shows Vietnamese message [v1.1 | 2026-10-31] |
| TC-C21 | acceptance | AC-26, 27 | Confirm; complete a Confirmed order due in 5 days; decline the confirmation | Confirm at once; Complete asks naming the code; declined leaves status; no action left on Completed; New offers no Complete [v1.1 | 2026-10-31] |
| TC-C22 | acceptance | AC-28 | Cancel: open step, back, reason list, confirm | Exactly four reasons; confirm disabled until one chosen; confirmation names the code; back keeps status [v1.1 | 2026-10-31] |
| TC-C23 | acceptance | AC-29 | Stub returns conflict on a stale view; double tap on Confirm | Current status with Vietnamese message; no action on final states; repeat shows Confirmed, no error [v1.1 | 2026-10-31] |
| TC-C24 | acceptance | AC-30 | Count taps from the order for Confirm, Complete, Cancel | Confirm 1 tap; Complete 1 tap + 1 confirmation; Cancel 1 tap + 1 screen with reason and confirm [v1.1 | 2026-10-31] |
| TC-C25 | acceptance | AC-31 | Tap notification (injected) signed in; with app closed use icon then the order row | 1 tap to detail; 2 taps from the icon [v1.1 | 2026-10-31] |
| TC-C26 | acceptance | AC-32, 33, 34 | Edit price; hide the last active cake; add cake with JPEG, PNG, HEIC from the picker, GIF, 6 MB; 13th cake; remove a cake | Saved values shown; last-active message; HEIC converted to JPEG and accepted, GIF/6 MB refused with message; 13th message; removal confirmation names the cake; no control to change an existing cake's image [v1.1 | 2026-10-31] |
| TC-C27 | acceptance | AC-35 | Lower the limit below accepted dates | Warning lists dates and cake counts before save; save and cancel both work [v1.1 | 2026-10-31] |
| TC-C28 | negative | AC-36, 40 | Invalid forms (lead 15, minimum 0, minimum above limit, price 0, empty shop name, 301-char greeting, bad slot, bad phone) | Message names the field; nothing saved; form keeps input [v1.1 | 2026-10-31] |
| TC-C29 | acceptance | AC-37, 38, 39 | Add/off district; add/off slot; last district; save shop info | Messages and lists update; last-active message in Vietnamese [v1.1 | 2026-10-31] |
| TC-C30 | acceptance | AC-48 | Owner opens Settings | Exactly five entries (Cakes, Ordering, Delivery, Shop info, Staff), each opens one screen or list, no further menu [v1.1 | 2026-10-31] |
| TC-C31 | acceptance | AC-42, 43 | Inject push; tap signed in, signed out, app killed; permission denied | Text has code, cakes, date only; order opens (after sign-in); app fully usable with notifications denied. Real APNs/FCM Blocked [v1.1 | 2026-10-31] |
| TC-C32 | acceptance | AC-44, 45 | Sign out, sign out others (on the other phone); inspect storage, cache, logs, app-switcher snapshot | No customer name, phone or address remains; snapshot hides data [v1.1 | 2026-10-31] |
| TC-C33 | acceptance | AC-46 | Customer app (both) places a 6th order after a "customer asked" cancel and after a "fake or spam" cancel | First accepted; second shows the rate-limit message [v1.1 | 2026-10-31] |
| TC-C34 | acceptance | AC-32, 36, 39 | Customer apps (both) after price, lead days, minimum, greeting changes | Customer app shows current price, earliest date, minimum, greeting after refresh; cart with old minimum told and can adjust [v1.1 | 2026-10-31] |

## 4.17 Extra client cases

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-C35 | extra | AC-29 | Confirm tapped twice fast; tap during a slow response | One request; button disabled while pending [v1.1 | 2026-10-31] |
| TC-C36 | extra | NFR a11y | Largest font; screen reader; contrast of status and red marks; badge label | No clipping; controls labelled; marks and badge read aloud with text; 4.5:1 [v1.1 | 2026-10-31] |
| TC-C37 | extra | AC-20 | Background 10 min then foreground | List and badge refresh on open [v1.1 | 2026-10-31] |
| TC-C38 | extra | AC-29 | Network lost during status change; retry | Error with retry; after retry one record; no false success [v1.1 | 2026-10-31] |
| TC-C39 | extra | AC-43 | Notification tap for an order cancelled meanwhile | Detail shows Cancelled with reason, no action [v1.1 | 2026-10-31] |
| TC-C40 | extra | AC-43 | Tap a notification while signed in as another account | Sign-in first; detail only if that account may see it; no data of the previous account [v1.1 | 2026-10-31] |
| TC-C41 | extra | NFR | Money and dates | `dd/MM/yyyy`, `1.234.000`; same on both platforms [v1.1 | 2026-10-31] |
| TC-C42 | extra | NFR | Rotation, dark mode, phone language not Vietnamese | Vietnamese text; layout intact [v1.1 | 2026-10-31] |
| TC-C43 | extra | AC-44 | Second user signs in on the same phone after sign-out | Previous list not visible; push to the new user only [v1.1 | 2026-10-31] |
| TC-C44 | regression | PRD section 9 | Customer apps with 12 cakes, long names, owner images, and with 1 cake | List scrolls, images load, placeholders; ordering works [v1.1 | 2026-10-31] |
| TC-C45 | extra | FR-9 | Device clock and time zone set to another country | "Today" filter and red marks use the server shop date [v1.1 | 2026-10-31] |
| TC-C46 | extra | AC-1 | E-mail keyboard, autocorrect, capital first letter, trailing space, paste | Address trimmed; case-insensitive [v1.1 | 2026-10-31] |
| TC-C47 | extra | AC-10 | Owner switches staff off while the staff app is open on an order | Within 5 min the next request ends in the sign-in screen; no data kept [v1.1 | 2026-10-31] |
| TC-C48 | negative | deferred | Walk every screen and string table (both platforms) | No device list, backup e-mail, recovery, Unfinished view/chip/banner, history screen, push settings or reminder text; no leftover accessibility ids of them [v1.1 | 2026-10-31] |
| TC-C49 | extra | AC-3 | Back / swipe-back and process kill during code entry; paste of the code | State restored or restarts cleanly; clipboard code accepted [v1.1 | 2026-10-31] |
| TC-C50 | extra | AC-16 | Open the app at 23:59 and 00:01 shop time (clock set) | Marks and badge roll over at midnight; "due today" becomes "overdue 1 day" [v1.1 | 2026-10-31] |
| TC-C51 | extra | AC-17 | Badge with 99 and 100 overdue; badge after sign-out and sign-in as another account | "99" then "99+"; no stale number of the previous account [v1.1 | 2026-10-31] |

## 4.18 Contract fixtures (to be created as `contracts/fixtures/admin-*.json`)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-F01 | acceptance | AC-14..17 | Backend golden test for each admin response (sign-in, refresh, sign-out-others, list page with overdue mark and count, detail, settings, cake, errors incl. conflict, forbidden, rate limited, validation with field name) | Server output equals the fixture shape; error codes come from the shared enum [v1.1 | 2026-10-31] |
| TC-F02 | acceptance | FR-9..19 | iOS `BanhContracts` decodes every `admin-*` fixture | All decode; unknown fields tolerated [v1.1 | 2026-10-31] |
| TC-F03 | acceptance | FR-9..19 | Android decodes the same fixtures | Same as TC-F02; same displayed values [v1.1 | 2026-10-31] |
| TC-F04 | negative | contract | Missing optionals (no note, no reason, no slot) and unknown status or unknown cancel reason | Clients show a safe state; never crash [v1.1 | 2026-10-31] |
| TC-F05 | extra | public repo | Scan fixtures for real e-mails, phones, tokens, hostnames, the review code | Only `example.com`, `+84 900 000 0xx`, placeholders [v1.1 | 2026-10-31] |
| TC-F06 | acceptance | AC-43 | Push payload fixture | Keys: code, cake count, delivery date, order id; no name, phone, address, note [v1.1 | 2026-10-31] |
| TC-F07 | extra | AC-46 | Place-order fixtures `order-error-rate-limited`, `catalog-ok` (12 cakes, image URLs) still decode on both customer apps | No regression [v1.1 | 2026-10-31] |
| TC-F08 | acceptance | AC-16, 17 | List fixture: overdue mark field (today / overdue N), count above 99, no mark for future and final orders | Both clients render the same text; count 99+ rule identical [v1.1 | 2026-10-31] |
