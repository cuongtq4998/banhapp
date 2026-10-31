# Admin Orders: Acceptance Criteria, history, settings, notifications (section 7, part 2)

Part of [Admin Orders](../admin-orders.md) (PRD v1.1). Holds: AC-31 to AC-72. Sample data is fake, as in part 1; backup e-mail chu.mau.backup@example.com, new staff "Nhan Vien C" nhanvien.c@example.com. [v1.1 | 2026-10-31]

## 7. Acceptance Criteria (continued)

### 7.4 History and settings

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-31 | FR-20, BR-4 | Given an order created by a customer, confirmed by "Nhan Vien A" and completed by "Chu Mau", then its history lists "created by customer", then the two changes, each with old status, new status, account name and date and time, oldest first. A cancellation entry also shows its reason. No screen or request can edit or delete a history entry. [v1.1 | 2026-10-31] |
| AC-32 | FR-21 | Given a staff account signed in, then only the order area shows and no settings or staff entry exists. Given the owner, then the order area and the settings area both show. |
| AC-33 | FR-22 | Given a cake priced 120 000, when the owner saves 130 000, then the customer catalog returns 130 000 on its next request and the settings screen shows 130 000. Name, description and active flag can be changed the same way. |
| AC-34 | FR-22, BR-11, BR-12 | Given 4 active cakes, when the owner hides one, then the customer catalog returns 3 and an order containing the hidden cake is refused by the server; showing it again returns it to the catalog. Given only 1 active cake, when the owner tries to hide it, then the change is refused with a message that at least one cake must stay active. [v1.1 | 2026-10-31] |
| AC-35 | FR-23 | Given the owner adds district "Quan Mau" with fee 25 000, then customers can choose it and the order total uses 25 000. Changing its fee to 30 000 changes the total of new orders only. |
| AC-36 | FR-23, BR-11 | Given a district is deactivated, then customers can no longer choose it, an order for it is refused by the server, and earlier orders for it still show it. Given it is the last active district, then the deactivation is refused with a message. |
| AC-37 | FR-24 | Given limit 100, when the owner saves 150, then a date with 120 cakes accepted is available for an order of 30 cakes. |
| AC-38 | FR-24, BR-10 | Given dates 05/11 with 98 cakes and 06/11 with 40 cakes accepted, when the owner enters limit 60, then before saving the owner sees that 05/11 (98 cakes) is above the limit; after saving, both orders on 05/11 remain unchanged, 05/11 shows as full to customers, and 06/11 can take up to 20 more cakes. |
| AC-39 | FR-25 | Given slots 08:00 to 10:00 and 10:00 to 12:00, when the owner adds 14:00 to 16:00, then customers can choose it. When the owner deactivates 08:00 to 10:00, then customers can no longer choose it and earlier orders still show it. |
| AC-40 | FR-25, BR-9, BR-11 | Given a slot with end 09:00 and start 10:00, or a duplicate of an existing slot, then saving is refused with a message. Given the last active slot, then deactivation is refused. |
| AC-41 | FR-26 | Given the owner saves a new greeting and Zalo contact, then the customer shop information shows them at its next refresh. A phone number that is not valid is refused. |
| AC-42 | FR-27 | Given the owner adds "Nhan Vien C" with nhanvien.c@example.com, then that address can request a code (AC-1) and sign in as staff, and the account list shows name, e-mail and role. [v1.1 | 2026-10-31] |
| AC-43 | FR-27, BR-7, BR-8 | Given the address is already on an account (also with different letter case) or is the owner's backup e-mail, then adding it is refused. Given 30 active staff, then adding a 31st is refused. Given the owner account, then there is no way to deactivate it. An address without a valid e-mail format is refused. [v1.1 | 2026-10-31] |
| AC-44 | FR-27 | Given a deactivated staff account, when the owner reactivates it, then that person can sign in again, and earlier history entries still show the same name. |
| AC-45 | FR-28, BR-9 | Given price 0, fee 0, limit 0, limit 10 000, empty shop name or a 301-character greeting, when saved, then each is refused with a message naming the field, and no value of that form is stored. |
| AC-46 | FR-29, BR-12 | Given a stored order of 2 cakes at 120 000 with fee 20 000 (total 260 000), when the owner raises the price to 130 000 and the fee to 25 000, then opening that order still shows 120 000, fee 20 000, total 260 000. |
| AC-47 | FR-30 | Given the owner changes a price from 120 000 to 130 000, then a record exists with the owner's name, the field, the old value, the new value and the time. |

### 7.5 Notifications and sign-out data

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-48 | FR-31, G-1 | Given 2 devices signed in with notifications allowed and 1 signed in with them denied, when a customer's order is stored, then both allowed devices receive a notification within 60 seconds in normal network conditions, and the third device shows the order after refresh. |
| AC-49 | FR-32, BR-14 | Given an order with name "Tran Thi B", phone +84 900 000 010 and a note, then the notification text contains the order code, the number of cakes and the delivery date, and none of the name, phone, address or note. |
| AC-50 | FR-33 | Given a signed-in device, when the notification is tapped, then the detail of that order opens. Given the session ended, then sign-in shows first and the detail opens after sign-in. |
| AC-51 | FR-34 | Given notifications are denied on the device, then all order and settings functions work and a hint on how to allow notifications shows once for that sign-in. |
| AC-52 | FR-35, BR-15 | Given a device signs out, then a new order sends it no notification and no customer name, phone or address remains readable in the app on that device. Given an account is deactivated or a device is revoked, then that device receives no further notification. [v1.1 | 2026-10-31] |

### 7.6 Sessions, devices and recovery (new in v1.1)

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-53 | FR-36, BR-6 | Given a signed-in device used every 5 days for 20 days, then it never asks for a code. Each use gives it a new renewal credential and the previous one stops working. [v1.1 | 2026-10-31] |
| AC-54 | FR-36 | Given a device already renewed its credential, when the old credential is presented again, then the request is refused and that device is signed out and shows the sign-in screen. [v1.1 | 2026-10-31] |
| AC-55 | FR-37, G-4 | Given staff "Nhan Vien A" is signed in on two devices, when the owner revokes one, then that device cannot renew at once, loses data access within 5 minutes and shows the sign-in screen; the other device keeps working. [v1.1 | 2026-10-31] |
| AC-56 | FR-37, BR-1 | Given a staff member, then the device list shows only that person's own devices, and a request to revoke another person's device is refused. Given the owner, the list shows all accounts' devices with account name, device name and last used. [v1.1 | 2026-10-31] |
| AC-57 | FR-42 | Given the owner enters chu.mau.backup@example.com as backup e-mail, then it is saved only after the code sent to it is entered. Given the same address as the owner's sign-in address or a staff address, then it is refused. [v1.1 | 2026-10-31] |
| AC-58 | FR-43, BR-17 | Given a backup e-mail is registered, when the owner starts recovery sign-in on a new device, then two different codes are sent, one to each address; sign-in succeeds only when both are entered correctly; a notice is then sent to both addresses and the device list is offered. [v1.1 | 2026-10-31] |
| AC-59 | FR-43, BR-17 | Given only one of the two codes is correct, then recovery is refused and no session exists. Given no backup e-mail is registered, then recovery sign-in is not offered. [v1.1 | 2026-10-31] |

### 7.7 Cakes and ordering rules (new in v1.1)

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-60 | FR-38 | Given the owner enters name "Banh Mau", description, price 150 000 and a JPEG of 2 MB, when saved, then the cake is active and the customer catalog returns it with its image at its next request. [v1.1 | 2026-10-31] |
| AC-61 | FR-38, BR-18 | Given no image, a GIF, an image of 6 MB, price 0, an empty name or a name used by another cake, when saved, then each is refused with a message naming the field and no cake is created. Given 12 cakes not removed, then adding a 13th is refused with a message. [v1.1 | 2026-10-31] |
| AC-62 | FR-39, BR-19 | Given cake "Banh Mau" appears in 3 earlier orders at 150 000, when the owner confirms its removal, then the customer catalog no longer returns it, an order containing it is refused by the server, and the 3 earlier orders still show "Banh Mau", quantity and 150 000 in the admin app. [v1.1 | 2026-10-31] |
| AC-63 | FR-39, BR-11 | Given only 1 active cake, when the owner tries to remove it, then removal is refused with a message that at least one cake must stay active. Given a removed cake, then the settings list does not show it and no screen restores it. [v1.1 | 2026-10-31] |
| AC-64 | FR-40, BR-21 | Given lead days 2 and an order stored for 03/11, when the owner saves lead days 3, then that order is unchanged and a new order for 03/11 placed on 01/11 is refused, and the customer app shows the earliest date under 3 lead days. [v1.1 | 2026-10-31] |
| AC-65 | FR-40, BR-21 | Given minimum cakes 2, when the owner saves 3, then an earlier order of 2 cakes stays valid, new orders of 2 cakes are refused, and the customer app text states the minimum of 3. A customer who had 2 cakes in the cart is told the new minimum and can change the quantity. [v1.1 | 2026-10-31] |
| AC-66 | FR-40, FR-28, BR-9 | Given lead days 15, minimum cakes 0, or minimum cakes above the daily limit, when saved, then each is refused with a message naming the field and nothing in the form is stored. [v1.1 | 2026-10-31] |

### 7.8 Order window, cancel reasons, limit on repeat orders (new in v1.1)

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-67 | FR-41, BR-20 | Given orders placed 89 days ago and 91 days ago, then the list, search and status filters show the first and never the second; a direct request for the second is refused. The same holds for the owner. [v1.1 | 2026-10-31] |
| AC-68 | FR-41 | Given an order placed 89 days ago, when the app is opened 2 days later, then that order is no longer shown. [v1.1 | 2026-10-31] |
| AC-69 | FR-18, BR-16 | Given the cancel step, then exactly five reasons are offered: customer asked, day full, cannot deliver, cannot reach customer, fake or spam order. After cancelling, the detail and the history show the chosen reason. [v1.1 | 2026-10-31] |
| AC-70 | FR-44, BR-16 | Given phone +84 900 000 010 placed 5 orders in 24 hours and one is cancelled with "customer asked", when the same phone orders again, then the order is accepted. [v1.1 | 2026-10-31] |
| AC-71 | FR-44, BR-16 | Given 5 orders from one phone in 24 hours and one is cancelled with "fake or spam order", when the same phone orders again within that 24 hours, then the order is refused by the place-order limit. [v1.1 | 2026-10-31] |
| AC-72 | FR-44 | Given 5 orders from one phone, 2 cancelled with "cannot deliver", 1 cancelled with "fake or spam order" and 2 still open, then 3 count toward the limit and 2 more orders are accepted, the third is refused. [v1.1 | 2026-10-31] |
