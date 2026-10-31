# Admin Orders Test Plan: Backend cases, Settings (cakes, ordering, delivery, shop info) (part 05)

Part of [admin-orders-test-plan.md](../admin-orders-test-plan.md) (v1.1). Holds: TC-B107 to TC-B145. Same columns as [part 03](03-cases-backend-auth.md). Every result is `Not run`. Owner session unless stated. [v1.1 | 2026-10-31]

## 4.12 Cakes (FR-21, BR-11, BR-12)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B107 | acceptance | AC-32 | Cake price 120 000 to 130 000; edit name and description | Catalog returns new values at the next request [v1.1 | 2026-10-31] |
| TC-B108 | extra | AC-32 | Reason: caching. Fetch catalog, change price, send `If-None-Match` with the old tag | 200 with the new body, never 304; tag changes for every catalog-visible change [v1.1 | 2026-10-31] |
| TC-B109 | acceptance | AC-32 | 4 active cakes, hide one; order with it; show it; hide/remove the only active cake | Catalog 3; order refused (`product-unavailable`); shown returns; last active cannot be hidden or removed (message) [v1.1 | 2026-10-31] |
| TC-B110 | extra | AC-32 | Two owner phones hide the last two active cakes in parallel; same for last district and last slot | At least one stays active; one request refused [v1.1 | 2026-10-31] |
| TC-B111 | acceptance | AC-33 | "Banh Mau", description, 150 000, JPEG 2 MB | Cake active; catalog returns it with an image URL that serves the image [v1.1 | 2026-10-31] |
| TC-B112 | negative | AC-33 | No image; GIF; price 0; empty name; duplicate name (other case); each alone | Each refused with a message naming the field; no cake row, no file stored [v1.1 | 2026-10-31] |
| TC-B113 | edge | AC-33 | JPEG of 5 242 880 bytes and of 5 242 881 bytes; 5 000 000 bytes | 5 242 880 and 5 000 000 accepted; 5 242 881 refused [v1.1 | 2026-10-31] |
| TC-B114 | extra | AC-33 | 12 not removed cakes (active and hidden mixed), add a 13th; remove one, add again; two adds in parallel at 11 | 13th refused; add works after removal; parallel gives 12 not 13 [v1.1 | 2026-10-31] |
| TC-B115 | negative | AC-33 | PNG named .jpg and reverse; SVG; HTML with image header; JPEG+ZIP polyglot; truncated JPEG; 0 bytes; HEIC bytes; 30 000 x 30 000 PNG; animated PNG; two image parts; file name `../x` | Only real JPEG/PNG accepted, by content; others refused without 500 or timeout; bomb refused; name never a path; EXIF location not served [v1.1 | 2026-10-31] |
| TC-B116 | negative | AC-33 | Upload 5 MB while the global body limit is 8 KB | Cake route allows the image; every other route still answers 413 above 8 KB [v1.1 | 2026-10-31] |
| TC-B117 | extra | AC-33 | Staff and anonymous post a cake; read the image URL headers; image URL of a removed cake | Staff 403 and no file stored; served type matches content with `nosniff`; removed image not listed [v1.1 | 2026-10-31] |
| TC-B118 | negative | FR-21 | Change the image of an existing cake (PUT/PATCH with image part, replace route) | Refused or ignored; stored image unchanged; no route exists to replace it [v1.1 | 2026-10-31] |
| TC-B119 | acceptance | AC-34 | "Banh Mau" in 3 orders at 150 000; remove it | Catalog excludes it; new order refused; settings list omits it; the 3 orders show name, quantity, price [v1.1 | 2026-10-31] |
| TC-B120 | extra | AC-34 | Reuse a removed cake's name; edit, hide or restore a removed cake by id | Name reuse allowed; edit refused; no restore route [v1.1 | 2026-10-31] |
| TC-B121 | extra | AC-34 | Order with the cake in parallel with its removal | Order complete before (valid) or refused; never half-stored [v1.1 | 2026-10-31] |

## 4.13 Ordering (FR-22, BR-11)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B122 | acceptance | AC-35 | Limit 100 to 150, date with 120 accepted, order of 30 | Accepted [v1.1 | 2026-10-31] |
| TC-B123 | acceptance | AC-35 | 05/11 has 98, 06/11 has 40; preview, then save limit 60 | Preview lists 05/11 (98); after save orders stay, 05/11 full, 06/11 takes 20 not 21 [v1.1 | 2026-10-31] |
| TC-B124 | extra | AC-35 | Preview, an order arrives, then save | Save uses the state at save time; preview advisory; no 500 [v1.1 | 2026-10-31] |
| TC-B125 | extra | AC-36 | Limit 10, minimum 5; save limit 3 alone | Refused (minimum above limit on the saved pair), or accepted into a stuck state: result recorded (R-11) [v1.1 | 2026-10-31] |
| TC-B126 | acceptance | AC-36 | Lead days 2, order stored for 03/11; save 3; new order for 03/11 placed 01/11; availability | Old order unchanged; new refused with the current rule; earliest date moves [v1.1 | 2026-10-31] |
| TC-B127 | acceptance | AC-36 | Minimum 2 to 3; 2-cake order; earlier order of 2 | New refused with minimum 3 shown; earlier order valid [v1.1 | 2026-10-31] |
| TC-B128 | negative | AC-36 | Lead days 15; minimum 0; minimum above limit | Each refused naming the field; nothing of the form stored [v1.1 | 2026-10-31] |
| TC-B129 | acceptance | AC-36 | Limit 5 and minimum 10 stored (setup via SQL): save limit 5 alone; save limit 5 + minimum 3 | First refused; second accepted [v1.1 | 2026-10-31] |
| TC-B130 | edge | AC-40 | Lead 0, 14, -1, 14.5; minimum 1, 20, 21; limit 1, 9 999, 10 000, 0 | 0, 14, 1, 20, 1, 9 999 accepted; others refused; lead 0 same-day behaviour recorded [v1.1 | 2026-10-31] |
| TC-B131 | extra | BR-11 | Order in progress (review step) when rules change | Server refuses with the current value; stored orders never altered or cancelled [v1.1 | 2026-10-31] |

## 4.14 Delivery and Shop info (FR-23, FR-24, BR-11)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B132 | acceptance | AC-37 | Add "Quan Mau" fee 25 000, order, change fee to 30 000, switch off; switch off the last active district | New totals 25 000 then 30 000; old order unchanged; off removes it from choices and new orders; old orders show it; last refused [v1.1 | 2026-10-31] |
| TC-B133 | extra | AC-37 | District name unique ignoring case and spaces; rename; fee 0, 1, 10 000 000, 10 000 001 | Duplicate refused; old orders keep stored name; fee bounds per BR-11 [v1.1 | 2026-10-31] |
| TC-B134 | acceptance | AC-38 | Slots 08-10, 10-12; add 14-16; switch off 08-10 | 14-16 selectable; 08-10 not for new orders; old orders keep 08-10 [v1.1 | 2026-10-31] |
| TC-B135 | negative | AC-38 | Slot 10:00-09:00, start = end, duplicate, 24:00, 08:60, switch off last active | Each refused with a message; slot list unchanged [v1.1 | 2026-10-31] |
| TC-B136 | extra | AC-38 | Change an existing slot's times; overlapping slots 08-10 and 09-11 | Old orders keep stored slot; overlap behaviour recorded (BR-11 forbids only duplicates) [v1.1 | 2026-10-31] |
| TC-B137 | acceptance | AC-39 | Save new greeting and Zalo contact; contact phone `0900 000 010`, `+84900000010`, `84900000010` | Customer app data shows new values at next refresh; three phone forms accepted [v1.1 | 2026-10-31] |
| TC-B138 | negative | AC-39 | Phone `090000001`, `abc`, `+84`, 30 digits; Zalo name `banh.mau.zalo`, `ab`, 101 characters, 100 characters | Phones refused; Zalo accepted at 3 and 100, refused at 2 and 101; no 500 [v1.1 | 2026-10-31] |

## 4.15 Validation, stored orders, record (BR-11, BR-3)

| ID | Type | Traces | Steps and data | Expected |
| -- | ---- | ------ | -------------- | -------- |
| TC-B139 | negative | AC-40 | Price 0, 1, 100 000 000, 100 000 001; fee 0, 1, 10 000 000, 10 000 001; limit 0, 10 000; empty shop name; greeting 300 and 301; cake name 100 and 101 | Bounds per BR-11; each refusal names the field; nothing stored [v1.1 | 2026-10-31] |
| TC-B140 | extra | AC-40 | Form with one valid and one invalid field; repeat with 5 fields | Whole form refused; no field stored (transaction) [v1.1 | 2026-10-31] |
| TC-B141 | extra | AC-40 | Names with only spaces, HTML `<b>`, emoji, diacritics NFC and NFD, control characters, null byte | Trimmed/validated; never interpreted; NFC/NFD duplicates detected or recorded (R-13) [v1.1 | 2026-10-31] |
| TC-B142 | negative | AC-40 | Prices as `"150000"`, `150000.5`, `1e5`, `9223372036854775808`, negative, null | Whole numbers only; overflow refused; no 500 [v1.1 | 2026-10-31] |
| TC-B143 | extra | AC-40 | Two owner phones save the same value, and different values from the same old state | Last save wins (BR-11); both saves recorded; no 500 [v1.1 | 2026-10-31] |
| TC-B144 | acceptance | AC-41 | Order 2 cakes at 120 000, fee 20 000 (260 000); price 130 000, fee 25 000; open it | Still 120 000, 20 000, 260 000 [v1.1 | 2026-10-31] |
| TC-B145 | extra | AC-47 | Every Settings call (cake add/remove/hide, staff add/switch, districts, slots, ordering, shop info); refused calls | One record per accepted change; none for refused; records immutable [v1.1 | 2026-10-31] |
