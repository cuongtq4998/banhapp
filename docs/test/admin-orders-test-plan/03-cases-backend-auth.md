# Admin Orders Test Plan: Backend cases, sign-in, sessions, roles, staff, notices (part 03)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: TC-B01 to TC-B48. Columns: id, type, traces, steps and data, expected. Every result is `Not run`. Type `extra` = added by the tester beyond the ACs. Rewritten for PRD v1.5 (27 FR, 14 BR, 48 AC); cases of deferred features are deleted. [v1.1 | 2026-10-31]

## 4.1 Sign-in codes (FR-1, FR-6, BR-4)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B01 | acceptance | AC-1 | Request a code for `nhanvien.a@example.com` and for `NhanVien.A@Example.com` (staff A active) | Success both; one mail each in the sink; code is 6 digits [v1.1 | 2026-10-31] |
| TC-B02 | acceptance | AC-1 | Request a code for `khong.co@example.com` | Status, body, headers equal TC-B01 (ignoring request id and date); sink empty [v1.1 | 2026-10-31] |
| TC-B03 | extra | AC-1 | Reason: enumeration by timing. 30 requests each, registered and unregistered; compare median time | Medians differ by less than the noise (no synchronous mail wait on one path) [v1.1 | 2026-10-31] |
| TC-B04 | acceptance | AC-2 | Code sent; submit the right digits at +9:59 for staff A and for the owner | Session issued (access and renewal credential); list readable; owner needs this one code only (no second code, no second step) [v1.1 | 2026-10-31] |
| TC-B05 | negative | AC-2 | Right digits at +10:00 and +10:01; the same code a second time after a success | All refused; no session row; at exactly 10:00 expired (`now < expires_at`) [v1.1 | 2026-10-31] |
| TC-B06 | acceptance | AC-3 | Request; +10 s request again; +29 s; +30 s | +10 s and +29 s refused with the seconds left; +30 s sent; the first code now fails, the second works [v1.1 | 2026-10-31] |
| TC-B07 | acceptance | AC-4 | 5 wrong entries for staff A, then the right digits; then request a new code at once (30 s passed) and enter it | After the 5th wrong entry the right digits are refused (code void, "request a new code"); no wait message with minutes; the new code works at once [v1.1 | 2026-10-31] |
| TC-B08 | acceptance | AC-4 | 3 requests in an hour (31 s apart), 4th request; again at +59:59 and +60:01 from the first | 4th refused with the wait; accepted again once the look-back of 60 minutes allows [v1.1 | 2026-10-31] |
| TC-B09 | acceptance | AC-4 | Staff A signed in on a phone; an attacker does 5 wrong entries and 4 requests for A's address; the phone renews and reads the list | Signed-in phone keeps working throughout (renewal, list); only code requests are limited [v1.1 | 2026-10-31] |
| TC-B10 | extra | AC-4 | 5 wrong entries and 4 requests for `khong.co@example.com` | Same refusals, texts and timing as a registered address (no enumeration through limits) [v1.1 | 2026-10-31] |
| TC-B11 | extra | AC-4 | Residual risk (R-3): attacker spends the 3 requests an hour for the owner address; owner asks for a code | Owner is refused with the wait. Recorded: availability of the owner address is still reducible without a lock; result goes to requirements [v1.1 | 2026-10-31] |
| TC-B12 | extra | AC-4 | 20 parallel wrong guesses for one code | At most 5 evaluated; the rest answer expired/void; no race lets 6 guesses through [v1.1 | 2026-10-31] |
| TC-B13 | extra | AC-2 | Two parallel submissions of the same right code | Exactly one session is created [v1.1 | 2026-10-31] |
| TC-B14 | negative | AC-1 | Code requested for staff A, submitted with staff B's address | Refused; counts as wrong for B's code only [v1.1 | 2026-10-31] |
| TC-B15 | extra | AC-2 | After a request and sign-in, read the code store and session store | No plain code or plain credential; hashes only [v1.1 | 2026-10-31] |
| TC-B16 | negative | AC-9 | Addresses: spaces around, upper case, `nhanvien.a+x@example.com`, two `@`, no `@`, `a@b`, `a b@example.com`, 254 and 255 characters, look-alike Unicode letters | Case and outer spaces ignored; invalid ones refused or treated as unregistered with the TC-B02 response; 254 accepted, 255 refused; look-alike never matches [v1.1 | 2026-10-31] |
| TC-B17 | negative | AC-2 | Code `12345`, `1234567`, `abcdef`, empty, ` 123456`, SQL text | Wrong-code or validation answer; no 500; counted as wrong only when well-formed (rule recorded) [v1.1 | 2026-10-31] |
| TC-B18 | extra | AC-1 | Deactivated staff B requests a code | Same response as TC-B02; no mail [v1.1 | 2026-10-31] |
| TC-B19 | extra | AC-4 | 60 code requests for distinct unregistered addresses from one client address in a minute | Per-client limit of the architecture (20 an hour per api/05) answers 429; behaviour recorded (PRD has none, R-6) [v1.1 | 2026-10-31] |

## 4.2 Sessions, sign out, sign out all other phones (FR-2, FR-4, FR-6, BR-5)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B20 | acceptance | AC-5 | Use the phone every 5 days for 20 days (clock jumps), keep each old renewal credential | Never asks for a code; each use returns a new credential; each older one is refused (after the 20 s grace) [v1.1 | 2026-10-31] |
| TC-B21 | edge | AC-5 | Idle 6 d 23 h 59 min, 7 d 0 h 0 min, 7 d 0 h 1 min | 6 d 23 h 59 min renews; 7 d exactly and later need a code [v1.1 | 2026-10-31] |
| TC-B22 | acceptance | AC-6 | Sign out; use the old access credential and the old renewal credential | Renewal refused; data request refused (record whether the old access credential works up to its 5 minutes, then compare with AC-6 "no longer works") [v1.1 | 2026-10-31] |
| TC-B23 | acceptance | AC-7 | Account on phone 1 and phone 2; call "sign out all other phones" from phone 1; phone 2 renews, then reads the list at once and at +5 min | Phone 2 renewal refused at once, data refused by +5 min; phone 1 keeps working, including its next renewal; no new code mail [v1.1 | 2026-10-31] |
| TC-B24 | extra | AC-7 | Reason: scope. Staff A calls it with one phone only; staff A calls it twice; owner calls it while staff B is signed in | Success with nothing to do, then same result; staff B and other accounts untouched; staff may call it (BR-1) [v1.1 | 2026-10-31] |
| TC-B25 | extra | AC-7 | Phone 2 renews in parallel with the sign-out-others call from phone 1 | After both finish phone 2 holds no valid renewal credential; no phone 1 session is revoked [v1.1 | 2026-10-31] |
| TC-B26 | acceptance | AC-11 | Renew once; present the old credential 21 s later | Refused; the phone's session is revoked, the new credential also fails; next call needs a code [v1.1 | 2026-10-31] |
| TC-B27 | acceptance | AC-11 | Send the same renewal request again at +1 s, +19 s, +20 s, +21 s (separate runs) | +1 s and +19 s succeed and the phone stays signed in; +21 s signs out; +20 s recorded (ADR-0022: boundary) [v1.1 | 2026-10-31] |
| TC-B28 | negative | FR-3 | Access credential with changed role claim (staff to owner), `alg=none`, wrong signature, expired by 1 s, another account's | All refused; no privilege change [v1.1 | 2026-10-31] |
| TC-B29 | acceptance | AC-10 | Staff B signed in on two phones; owner switches B off; B requests a code | Renewal fails at once on both; data refused by +5 min; no code mail to B [v1.1 | 2026-10-31] |
| TC-B30 | acceptance | AC-10 | Switch B on again with 29 active, then with 30 active | B signs in with a new code; old sessions stay dead; records keep B's name; at 30 refused with the "switch one off first" message [v1.1 | 2026-10-31] |

## 4.3 Authorization and roles (FR-3, FR-20, BR-1)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B31 | negative | AC-8 | Call every admin order and settings route without credentials | 401 on all; no order or settings data in the body [v1.1 | 2026-10-31] |
| TC-B32 | extra | AC-8 | Sweep: each admin route x {none, expired, staff, owner, deactivated staff, signed-out phone, review account}. Reason: no route may be forgotten | Result table matches BR-1 on every cell; the route list is generated from the router [v1.1 | 2026-10-31] |
| TC-B33 | negative | AC-8 | Staff session: change price, add/remove/hide cake, ordering values, add district, add slot, shop info, add staff, switch staff off | 403 on all; database unchanged (checksum of settings and account tables before and after) [v1.1 | 2026-10-31] |
| TC-B34 | extra | AC-8 | Escalation: add-staff body with `role=owner`; patch own role; mass-assignment fields (`is_active`, `id`); read owner-only ids (IDOR) | Fields ignored or refused; still exactly one owner [v1.1 | 2026-10-31] |
| TC-B35 | negative | AC-8 | PUT, PATCH (content), DELETE on an order; scan every response for payment fields | 404 or 405; no edit or delete of an order; no payment data (BR-1) [v1.1 | 2026-10-31] |

## 4.4 Staff accounts (FR-5, BR-6)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B36 | acceptance | AC-9 | Owner adds "Nhan Vien C" `nhanvien.c@example.com`; C requests a code, signs in; owner lists accounts | C signs in as staff; list shows name and e-mail [v1.1 | 2026-10-31] |
| TC-B37 | negative | AC-9 | Add an existing address (other letter case), `a@b`, `a b@example.com`, a 31st active staff | Each refused naming the e-mail (31st: switch-off message); nothing changes [v1.1 | 2026-10-31] |
| TC-B38 | negative | AC-10 | Switch off the owner (API); delete the owner; switch off own account | All refused; owner stays active [v1.1 | 2026-10-31] |
| TC-B39 | extra | AC-9 | 29 active: two adds in parallel; 29 active + one switch-on in parallel with an add | Result 30, never 31; review account is not counted [v1.1 | 2026-10-31] |
| TC-B40 | extra | AC-9 | Staff name empty, 1, 100, 500 characters, script text; duplicate display names | Length limited or refused; text returned escaped; duplicates recorded (no rule in PRD) [v1.1 | 2026-10-31] |

## 4.5 New-device e-mail to the owner (FR-7, BR-13)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B41 | acceptance | AC-12 | Owner signs in with a code on a new installation | One mail to `chu.mau@example.com` only: phone model, time, advice to use "Sign out all other phones"; no code, no link, no customer data [v1.1 | 2026-10-31] |
| TC-B42 | negative | AC-12 | Owner renewal; staff A sign-in on a new phone; owner second sign-in while that installation has a live session; mail sink set to fail on the owner sign-in | No notice in the first three; with the failing sink sign-in still succeeds (201), failure only logged [v1.1 | 2026-10-31] |
| TC-B43 | extra | BR-13 | Device name with CR/LF, 60 and 61 characters, HTML | No header injection; escaped in the mail; 61 refused [v1.1 | 2026-10-31] |
| TC-B44 | extra | BR-13 | Owner signs out and signs in again on the same phone; two parallel owner sign-ins from two new phones | Rule recorded (PRD "phone not used before" vs "no live session", R-12); two phones give two mails, one each; no mail goes to any other address [v1.1 | 2026-10-31] |

## 4.6 Review account (FR-8, BR-14)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B45 | acceptance | AC-13 | Switch on; `review.demo@example.com` enters its fixed code (from test configuration) | Signs in as staff; list shows exactly 3 demo orders, no real one; real accounts never see a demo order [v1.1 | 2026-10-31] |
| TC-B46 | acceptance | AC-13 | Switch off; same address and code; compare with an unregistered address | Refused with the TC-B02 response style; sink empty [v1.1 | 2026-10-31] |
| TC-B47 | extra | AC-13 | With the account on: a real order is stored; demo orders are confirmed and cancelled | No push for demo or to the review phone; day capacity and the per-phone limit unchanged; badge count of others unchanged [v1.1 | 2026-10-31] |
| TC-B48 | extra | AC-13 | Review account calls Settings and staff routes; 100 wrong guesses of the fixed code; repo scan for the fixed code | Settings 403; the fixed code is not brute-forceable beyond BR-4 limits (record result); no code in repo or documents [v1.1 | 2026-10-31] |
