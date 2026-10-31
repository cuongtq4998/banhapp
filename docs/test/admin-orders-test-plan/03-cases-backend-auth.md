# Admin Orders Test Plan: Backend cases, sign-in, sessions, roles, recovery (part 03)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: TC-B01 to TC-B52. Columns: id, type, traces, steps and data, expected result. Every result is `Not run`. Type `extra` = added by the tester beyond the ACs. [v1.0 | 2026-10-31]

## 4.1 Sign-in codes (FR-1 to FR-3, FR-6, BR-5, BR-7)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B01 | acceptance | AC-1 | Request a code for `NhanVien.A@Example.com` (staff A is active) | Success; one mail in the sink to the address; code is 6 digits |
| TC-B02 | acceptance | AC-2 | Request a code for `khong.co@example.com` | Status, body and headers equal TC-B01 (ignoring request id and date); sink empty |
| TC-B03 | extra | AC-2, FR-1 | Reason: enumeration by timing. 30 requests each for a registered and an unregistered address; compare median time | Medians differ by less than the noise (no synchronous mail wait on one path) |
| TC-B04 | acceptance | AC-3 | Code sent, +1 min, submit correct code | Session (access and renewal credential) issued; order list readable |
| TC-B05 | negative | AC-4 | Code sent, +11 min, submit correct code | Refused "expired"; no session row |
| TC-B06 | edge | AC-4, BR-5 | Submit at +9:59 and at +10:00 and +10:01 (two codes) | +9:59 accepted; the +10:00 behaviour is recorded (R-5 asks for inclusive or exclusive); +10:01 refused |
| TC-B07 | negative | AC-5 | Use a code, sign out, submit the same code again | Refused; no session |
| TC-B08 | acceptance | AC-6 | Request, +10 s request again; +30 s request again | +10 s refused with the seconds left; +30 s sent; the first code now fails, the second works |
| TC-B09 | acceptance | AC-8 | 5 wrong codes for staff A, then the correct code | Refused with "try again in 15 minutes"; no session |
| TC-B10 | edge | AC-8 | After the lock: try +14:59 and +15:01 with the correct code | +14:59 refused; +15:01 result recorded (code may have expired, 10 min, see R-4) |
| TC-B11 | acceptance | AC-9 | 3 requests in one hour (spaced 31 s), 4th request | 4th refused with the wait; after +60 min the request works |
| TC-B12 | extra | AC-6, BR-5 | Request code 1, +31 s request code 2, submit code 1 then code 2 | Code 1 fails (new code invalidates old); code 2 works. Reason: BR-5 rule 4 |
| TC-B13 | extra | AC-2 | 5 wrong codes and 4 requests for `khong.co@example.com` | Same refusals, texts and timing as a registered address (no enumeration through limits) |
| TC-B14 | extra | AC-8 | Lock owner address by an attacker with 5 wrong codes, then owner enters the right code, then tries recovery | Owner refused for 15 min (as specified). Recorded as risk R-3 (any outsider can lock the owner out); check whether recovery also locks |
| TC-B15 | extra | AC-8 | 20 parallel wrong guesses for one address | No more than 5 guesses are evaluated; the 6th+ answer lock; no race lets 6 guesses through |
| TC-B16 | extra | AC-5 | Two parallel submissions of the same correct code | Exactly one session is created |
| TC-B17 | negative | FR-2 | Code requested for staff A, submitted for staff B's address | Refused; counts as wrong for B |
| TC-B18 | extra | NFR security | After a request, read the code store and session store in the database | No plain code or plain credential; only hashes |
| TC-B19 | extra | BR-7, AC-1 | Addresses: leading and trailing space, upper case, `nhanvien.a+x@example.com`, two `@`, no `@`, 256 characters, Unicode look-alike letters | Case and space handled as the PRD says (case-insensitive); others refused as invalid or treated as unregistered with the same response as TC-B02; look-alike never matches |
| TC-B20 | extra | FR-1, FR-7 | Deactivated staff B requests a code | Same response as TC-B02; no mail |
| TC-B21 | negative | FR-2 | Code `12345`, `1234567`, `abcdef`, empty, ` 123456`, SQL text | Refused with a validation or wrong-code answer; no 500; wrong-code counting rule recorded |
| TC-B22 | extra | AC-9, BR-5 | 60 code requests for distinct unregistered addresses from one client address within a minute | Limit behaviour recorded; the PRD has no per-client limit (R-6) so this is expected to be unlimited: raise as a question |

## 4.2 Sessions and devices (FR-4, FR-7, FR-36, FR-37, BR-6, BR-8)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B23 | acceptance | AC-10 | Device last used 6 days ago refreshes; another last used 8 days ago | 6 days: renewed, no code; 8 days: refused, needs a new code |
| TC-B24 | edge | AC-10, BR-6 | Last used 6 d 23 h 59 min, 7 d 0 h 0 min, 7 d 0 h 1 min | Boundary result recorded; must be consistent with configuration (R-5) |
| TC-B25 | acceptance | AC-11 | Sign out; use the old access credential and the old renewal credential | Both refused on the server |
| TC-B26 | acceptance | AC-53 | Use the device every 5 days for 20 days (clock jumps); keep each old renewal credential | Never asks for a code; each use returns a new renewal credential; every older one is refused |
| TC-B27 | acceptance | AC-54 | Renew once, then present the old credential | Refused; the device's session is revoked, the new credential also fails; next call needs sign-in |
| TC-B28 | extra | FR-36 | Reason: network retry. Send the same renewal request twice in parallel | Exactly one succeeds. The second outcome (sign-out of a legitimate device) is recorded; a short grace policy is a question for the architect (R-12) |
| TC-B29 | negative | FR-5 | Access credential with changed role claim (staff to owner), `alg=none`, wrong signature, expired by 1 s, other account's | All refused; no privilege change |
| TC-B30 | acceptance | AC-14 | Staff B on two devices; owner deactivates B | Renewal fails at once on both; both are refused data by +5 min (access lifetime from configuration); no new code is sent for B |
| TC-B31 | acceptance | AC-55 | Staff A on two devices, owner revokes device 1 | Device 1 cannot renew at once, refused data by +5 min; device 2 keeps working |
| TC-B32 | acceptance | AC-56 | Staff A lists devices; tries to revoke staff B's device; owner lists | Staff sees only own devices; revoke of other's refused, nothing changes; owner sees all with account name, device name, last used |
| TC-B33 | extra | FR-37 | Staff A revokes the device it is using; owner revokes the owner's own current device | Behaves as sign-out; no lock-in; owner can sign in again |
| TC-B34 | extra | AC-44 | Reactivate staff B | Old sessions stay dead; B needs a new code; history keeps the same name |
| TC-B35 | extra | AC-55 | Revoke a device while its renewal request is in flight (parallel) | After both finish the device holds no valid credential |
| TC-B36 | extra | FR-37 | Device name of 1, 100 and 500 characters, script text; read device list | Length limited or refused; text returned escaped; no credential, token or IP in the list |

## 4.3 Authorization and roles (FR-5, FR-21, BR-1)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B37 | negative | AC-13 | Call every admin order, device and settings route without credentials | 401 on all; body has no order or settings data |
| TC-B38 | extra | AC-13 | Matrix sweep: each admin route x {none, expired, staff, owner, deactivated staff, revoked device}. Reason: no route may be forgotten | Result table matches the rights in BR-1 on every cell; the sweep list is generated from the router |
| TC-B39 | negative | AC-12 | Staff session calls: change price, add/remove/hide cake, lead days, minimum cakes, add district, slot, daily limit, shop info, add staff, deactivate staff, owner devices list, set backup e-mail | 403 on all; database unchanged (checksum of settings tables before and after) |
| TC-B40 | extra | FR-5 | Escalation: staff adds account with body field `role=owner`; staff patches own account role; sign-in body with `role`; mass-assignment fields (`is_active`, `id`); staff reads owner-only ids (IDOR) | Fields ignored or refused; still exactly one owner; no change |
| TC-B41 | negative | BR-1 | PUT, PATCH (content), DELETE on an order; read an order response for payment fields | 404 or 405; no endpoint edits or deletes an order; no payment data in any response |

## 4.4 Backup e-mail and recovery (FR-42, FR-43, BR-17)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B42 | acceptance | AC-57 | Owner sets `chu.mau.backup@example.com`; before the code, read the setting; then enter the code | Saved only after the code; same address as owner or as staff A refused |
| TC-B43 | extra | FR-42 | Change an existing backup: wrong code, expired code, right code; staff attempts | Old backup stays until confirmed; code goes only to the new address; staff refused |
| TC-B44 | acceptance | AC-58 | Recovery sign-in with backup set: both codes correct | Two different codes in the sink (one per address); session after both; notice mails to both; device list reachable |
| TC-B45 | negative | AC-59 | Owner code right, backup code wrong (and the reverse) | Refused; no session; the right code is not usable alone |
| TC-B46 | negative | AC-59 | Recovery with no backup registered | Not offered; no mail |
| TC-B47 | extra | BR-17 | Same code entered in both fields; codes swapped | Refused; no session |
| TC-B48 | extra | FR-43, BR-1 | Staff A address starts recovery | No mail, same response as an unregistered address, no session |
| TC-B49 | extra | FR-43 | After recovery, revoke the old device from the new one | Old device loses access; notice mails list time and new device name only (no credentials) |
| TC-B50 | extra | BR-5, BR-17 | One recovery code expired (+11 min), other valid; third recovery request in an hour; wrong codes lock | Rules of BR-5 apply to each mailbox; behaviour recorded where PRD is silent (R-7) |
| TC-B51 | extra | BR-7 | Add the backup address as a staff account; add the owner address as backup after removing | Refused both ways |
| TC-B52 | extra | BR-17 | While the owner address is locked (TC-B14), start recovery | Behaviour recorded; recovery must remain possible or a gap is reported (R-3) |
