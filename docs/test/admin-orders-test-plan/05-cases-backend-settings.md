# Admin Orders Test Plan: Backend cases, settings, cakes, staff, ordering rules (part 05)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.0). Holds: TC-B101 to TC-B143. Same columns as [part 03](03-cases-backend-auth.md). Every result is `Not run`. Owner session unless stated. [v1.0 | 2026-10-31]

## 4.10 Cakes (FR-22, FR-38, FR-39, BR-11, BR-12, BR-18, BR-19)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B101 | acceptance | AC-33 | Cake price 120 000 to 130 000; edit name, description, active flag too | Catalog and settings return new values at next request |
| TC-B102 | extra | AC-33 | Reason: catalog caching (ADR-0017 validator). Fetch catalog, change price, send `If-None-Match` with old tag | 200 with the new body, never 304; tag changes for every catalog-visible change (cake, district, slot, shop, rules) |
| TC-B103 | acceptance | AC-34 | 4 active cakes, hide one; place order with it; show it again; hide the only active cake | Catalog 3; order refused (`product-unavailable`); shown again returns; last active cannot be hidden (message) |
| TC-B104 | extra | BR-11 | Two owner devices hide the last two active cakes in parallel; same for last district, last slot | At least one stays active; one request refused. Reason: race on the invariant |
| TC-B105 | acceptance | AC-35 | Add district "Quan Mau" fee 25 000, order, change fee to 30 000 | Order total uses 25 000; old order unchanged; new order 30 000 |
| TC-B106 | acceptance | AC-36 | Deactivate a district; order for it; deactivate the last active district | Customers cannot choose; order refused; old orders still show it; last refused |
| TC-B107 | acceptance | AC-37 | Limit 100 to 150, date with 120 accepted, order of 30 | Accepted |
| TC-B108 | acceptance | AC-38 | 05/11 has 98, 06/11 has 40; preview and save limit 60 | Preview lists 05/11 (98); after save orders unchanged, 05/11 full, 06/11 takes 20, not 21 |
| TC-B109 | extra | BR-9 | Limit 10, minimum cakes 5; lower limit to 3 | Refused with field message (min above limit), or accepted with a stuck state: result recorded (R-11) |
| TC-B110 | extra | BR-10 | Preview, then an order arrives, then save | Save uses the state at save time; the preview is advisory; no 500 |
| TC-B111 | acceptance | AC-39 | Slots 08-10, 10-12; add 14-16; deactivate 08-10 | 14-16 selectable; 08-10 not; old orders still show 08-10 |
| TC-B112 | negative | AC-40 | Slot 10:00-09:00, start = end, duplicate slot, 24:00, 08:60, deactivate last active | Each refused with a message; slot list unchanged |
| TC-B113 | extra | FR-25, FR-29 | Change an existing slot's times; overlapping slots 08-10 and 09-11 | Old orders keep the stored slot; overlap behaviour recorded (BR-9 only forbids duplicates) |
| TC-B114 | acceptance | AC-41 | Save greeting and Zalo contact; invalid contact phone | Shop info shows new values at next refresh; invalid phone refused |
| TC-B115 | extra | BR-9 | Contact phone `abc`, `+84`, 30 digits, spaces; Zalo contact formats | Valid/invalid per a written rule (R-15); no 500 |
| TC-B143 | extra | FR-23, FR-29 | District name unique ignoring case and spaces; rename district; old orders | Duplicate refused; old orders keep the district name as stored |

## 4.11 Cake images and limits (FR-38, BR-18)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B125 | acceptance | AC-60 | "Banh Mau", description, 150 000, JPEG 2 MB | Cake active; catalog returns it with an image URL that serves the image |
| TC-B126 | negative | AC-61 | No image; GIF; 6 MB; price 0; empty name; duplicate name (also other case); each alone | Each refused with a field message; no cake row, no file stored |
| TC-B127 | extra | AC-61, FR-38 | 12 not removed cakes (mix of active and hidden), add 13th; remove one, add again; two adds in parallel at 11 | 13th refused; after removal add works; parallel gives 12 not 13 |
| TC-B128 | negative | AC-61 | Upload abuse: PNG named .jpg and the reverse; SVG; HTML or script with image header; JPEG+ZIP polyglot; truncated JPEG; 0 bytes; 5 MB exactly and 5 MB + 1 byte (both 5 000 000 and 5 242 880 readings); 30 000 x 30 000 pixel PNG; animated PNG; two image parts; path in file name `../x` | Only real JPEG/PNG within the size rule accepted, checked by content not by name or header; others refused without a 500 or timeout; decompression bomb refused; file name never used as path; EXIF location data not served |
| TC-B129 | negative | BR-18 | Upload 5 MB while the global body limit is 8 KB | The cake route allows the image size; every other route still answers 413 above 8 KB (R-16) |
| TC-B130 | extra | NFR security | Staff session posts a cake; no session posts; read the image URL: `Content-Type`, `X-Content-Type-Options`, `Content-Disposition`; image URL of a removed cake | Staff 403 and no stored file; served type matches content with `nosniff`; removed cake image not listed |
| TC-B131 | acceptance | AC-62 | "Banh Mau" in 3 orders at 150 000; remove it | Catalog excludes it; new order with it refused; the 3 orders show name, quantity, 150 000 |
| TC-B132 | acceptance | AC-63 | Remove the only active cake; list settings cakes; try to restore | Removal refused; removed cakes are not listed; no restore route |
| TC-B133 | extra | BR-19 | Reuse a removed cake's name; edit or hide a removed cake by id | Name reuse allowed (BR-18 says unique among not removed); edit refused |
| TC-B134 | extra | AC-62 | Order with the cake placed in parallel with its removal | Order either complete before (valid, handled normally) or refused; never half-stored |

## 4.12 Ordering rules and validation (FR-24, FR-28, FR-29, FR-40, BR-9, BR-21)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B135 | acceptance | AC-64 | Lead days 2, order for 03/11 stored; set lead 3; new order for 03/11 on 01/11; availability | Old order unchanged; new refused with current rule; earliest date moves |
| TC-B136 | acceptance | AC-65 | Min cakes 2 to 3; order of 2; earlier order of 2 | New 2-cake order refused (min-qty error with current value 3); earlier order valid |
| TC-B137 | negative | AC-66 | Lead days 15; min cakes 0; min above limit | Each refused naming the field; nothing in the form stored |
| TC-B138 | edge | BR-9 | Lead days 0, 14, -1, 14.5; min cakes 1, 20, 21; limit 1, 9 999, 10 000 | 0/14/1/20/9 999 accepted; others refused. Lead 0: same-day order behaviour recorded |
| TC-B120 | negative | AC-45 | Price 0, 1, 100 000 000, 100 000 001; fee 0, 1, 10 000 000, 10 000 001; limit 0, 10 000; empty shop name; greeting 300 and 301 characters; name 100/101 | Boundaries as BR-9; each refusal names the field |
| TC-B121 | extra | AC-45, FR-28 | Form with one valid and one invalid field (cake name + price); repeat with 5 fields | Whole form refused; no field stored (transaction) |
| TC-B139 | extra | BR-9 | Names with only spaces, HTML `<b>`, emoji, Vietnamese diacritics in NFC and NFD, control characters, null byte | Trimmed/validated; stored text is never interpreted; NFC/NFD duplicates detected or recorded (R-13) |
| TC-B140 | negative | BR-9 | Prices as `"150000"`, `150000.5`, `1e5`, `9223372036854775808`, negative, null | Whole numbers only; overflow refused; no 500 |
| TC-B141 | extra | FR-28 | Two owner devices edit the same cake/setting from the same old values | Defined outcome (version check or last write wins) recorded; audit shows both (R-17) |
| TC-B142 | extra | BR-21 | Order in progress (review step) when rules change | Server refuses with the current value; stored orders never altered or cancelled |
| TC-B122 | acceptance | AC-46 | Order 2 cakes at 120 000, fee 20 000 (260 000); raise price to 130 000, fee 25 000; open it | Still 120 000, 20 000, 260 000 |
| TC-B123 | acceptance | AC-47 | Change price 120 000 to 130 000 | One record: owner name, field, old, new, time |
| TC-B124 | extra | FR-30 | Audit for every settings call (cake add/remove, staff, backup e-mail, districts, slots, rules); try to edit or delete audit rows | Every change recorded once; refused changes not recorded; audit immutable |

## 4.13 Staff accounts (FR-27, BR-7, BR-8)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B116 | acceptance | AC-42 | Add "Nhan Vien C" `nhanvien.c@example.com`; request code; sign in; list accounts | Signs in as staff; list shows name, e-mail, role |
| TC-B117 | negative | AC-43 | Add existing address (other case), the backup address, `abc`, a 31st active staff; deactivate the owner | Each refused, nothing changes; owner cannot be deactivated or deleted |
| TC-B118 | extra | BR-8 | 29 active: two adds in parallel; 30 active + 1 deactivated: reactivate | Parallel gives 30 not 31; reactivation at 30 recorded (R-18); duplicate display names recorded |
| TC-B119 | acceptance | AC-44 | Deactivate then reactivate staff B | B signs in with a new code; history names unchanged |
