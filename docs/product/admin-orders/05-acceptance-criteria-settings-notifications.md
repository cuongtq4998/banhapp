# Admin Orders: Acceptance Criteria, settings, notifications, cross-feature (section 7, part 2)

Part of [Admin Orders](../admin-orders.md) (PRD v1.5). Holds: AC-32 to AC-48 (old ids in [08-deferred-and-id-mapping.md](08-deferred-and-id-mapping.md)). Sample data is fake as in part 1; new cake "Banh Mau". Every line is new or changed in v1.5 [v1.5 | 2026-10-31].

## 7. Acceptance Criteria (continued)

### 7.4 Settings

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-32 | FR-21 | Given a cake at 120 000, when the owner saves 130 000, then the customer catalog returns 130 000 at its next request. Name and description change the same way. Given 4 active cakes, when one is hidden, then the catalog returns 3 and an order with it is refused by the server; showing it brings it back. Given 1 active cake, hiding or removing it is refused with a message. [v1.5 | 2026-10-31] |
| AC-33 | FR-21, BR-12 | Given name "Banh Mau", description, price 150 000 and a JPEG of 2 MB, when saved, the cake is active and in the catalog. Refused with a message naming the field: no image, a GIF, 5 242 881 bytes (exactly 5 242 880 is accepted), price 0, empty or used name; a 13th cake is refused. An iPhone HEIC photo is converted to JPEG on the phone and then accepted under the same limit. [v1.5 | 2026-10-31] |
| AC-34 | FR-21, BR-12 | Given "Banh Mau" is in 3 earlier orders, when the owner confirms its removal, then the catalog no longer returns it, a new order with it is refused, the settings list does not show it, and the 3 orders still show its name, quantity and price. [v1.5 | 2026-10-31] |
| AC-35 | FR-22, BR-11 | Given limit 100, when 150 is saved, a date with 120 cakes can take 30 more. Given 05/11 with 98 and 06/11 with 40 cakes, when the owner enters 60, then before saving the owner is told 05/11 (98) is above it; after saving, the orders stay, 05/11 shows as full and 06/11 takes up to 20 more. [v1.5 | 2026-10-31] |
| AC-36 | FR-22, BR-11 | Given lead days 2 and an order stored for 03/11, when 3 is saved, that order is unchanged, a new order for 03/11 placed on 01/11 is refused and the customer app shows the new earliest date. Given minimum 2, when 3 is saved, a 2-cake order is refused with the new minimum shown. Lead days 15, minimum 0, or minimum above the limit are refused naming the field. Given limit 5 and minimum 10, saving limit 5 alone is refused; saving limit 5 and minimum 3 together is accepted. [v1.5 | 2026-10-31] |
| AC-37 | FR-23, BR-11 | Given district "Quan Mau" with fee 25 000 is added, customers can choose it and new totals use 25 000; changing it to 30 000 changes new orders only. Switching it off removes it from the customer choices and from new orders, earlier orders still show it; the last active district cannot be switched off. [v1.5 | 2026-10-31] |
| AC-38 | FR-23, BR-11 | Given slots 08:00 to 10:00 and 10:00 to 12:00, when 14:00 to 16:00 is added, customers can choose it. Switching off 08:00 to 10:00 removes it for new orders only. A slot with end before start, a duplicate, or switching off the last active slot is refused with a message. [v1.5 | 2026-10-31] |
| AC-39 | FR-24, BR-11 | Given a new greeting and Zalo contact are saved, the customer app shows them at its next refresh. Contact phone "0900 000 010", "+84900000010" and "84900000010" are accepted; "090000001" and "abc" are refused; Zalo account name "banh.mau.zalo" is accepted, "ab" refused. [v1.5 | 2026-10-31] |
| AC-40 | BR-11 | Given price 0, fee 0, limit 0, limit 10 000, an empty shop name or a 301-character greeting, when saved, each is refused with a message naming the field and nothing of that form is stored. [v1.5 | 2026-10-31] |
| AC-41 | BR-11 | Given a stored order of 2 cakes at 120 000 with fee 20 000 (total 260 000), when the price becomes 130 000 and the fee 25 000, the order still shows 120 000, 20 000 and 260 000. [v1.5 | 2026-10-31] |

### 7.5 Notifications, privacy, record, cross-feature

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-42 | FR-25, G-1 | Given 2 phones signed in with notifications allowed and 1 with them denied, when an order is stored, then both allowed phones are handed a notification within 60 seconds (measured on the server) and the third shows the order after refresh with every other function working. [v1.5 | 2026-10-31] |
| AC-43 | FR-26 | Given an order with name, phone and note, then the notification text holds the order code, number of cakes and delivery date and none of the name, phone, address or note. Tapping it opens the order, after sign-in first if the session ended. [v1.5 | 2026-10-31] |
| AC-44 | FR-25, BR-7 | Given a phone signs out, signs out all others, or the account is switched off, then it gets no further notification and no customer name, phone or address stays readable in the app. [v1.5 | 2026-10-31] |
| AC-45 | BR-7 | Given the app goes to the background on an order screen, then the phone preview shows no customer data. A request, push or crash report contains no customer name, phone, address or note, and no analytics tool receives data. [v1.5 | 2026-10-31] |
| AC-46 | FR-27, BR-8 | Given a phone placed 5 orders in 24 hours and one is cancelled with "customer asked" or "cannot deliver", then a further order is accepted. If it is cancelled with "fake or spam order", a further order within 24 hours is refused. [v1.5 | 2026-10-31] |
| AC-47 | BR-3 | Given an order created by a customer, confirmed by "Nhan Vien A", then a record holds each change with old and new status, name and time, and a cancellation also its reason; a price change from 120 000 to 130 000 records owner name, field, old and new value and time. No screen or request edits or deletes a record. [v1.5 | 2026-10-31] |
| AC-48 | FR-20 | Given the owner opens Settings, then exactly five entries show (Cakes, Ordering, Delivery, Shop info, Staff) and each opens one screen or list without further menus. [v1.5 | 2026-10-31] |
