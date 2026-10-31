# Admin Orders: Acceptance Criteria, history, settings, notifications (section 7, part 2)

Part of [Admin Orders](../admin-orders.md) (PRD v1.0). Holds: AC-31 to AC-52. Sample data is fake, as in part 1.

## 7. Acceptance Criteria (continued)

### 7.4 History and settings

| ID | FR | Given / When / Then |
| -- | -- | ------------------- |
| AC-31 | FR-20, BR-4 | Given an order created by a customer, confirmed by "Nhan Vien A" and completed by "Chu Mau", then its history lists "created by customer", then the two changes, each with old status, new status, account name and date and time, oldest first. No screen or request can edit or delete a history entry. |
| AC-32 | FR-21 | Given a staff account signed in, then only the order area shows and no settings or staff entry exists. Given the owner, then the order area and the settings area both show. |
| AC-33 | FR-22 | Given a cake priced 120 000, when the owner saves 130 000, then the customer catalog returns 130 000 on its next request and the settings screen shows 130 000. Name, description and active flag can be changed the same way. |
| AC-34 | FR-22, BR-11, BR-12 | Given 4 active cakes, when the owner hides one, then the customer catalog returns 3 and an order containing the hidden cake is refused by the server. Given only 1 active cake, when the owner tries to hide it, then the change is refused with a message that at least one cake must stay active. |
| AC-35 | FR-23 | Given the owner adds district "Quan Mau" with fee 25 000, then customers can choose it and the order total uses 25 000. Changing its fee to 30 000 changes the total of new orders only. |
| AC-36 | FR-23, BR-11 | Given a district is deactivated, then customers can no longer choose it, an order for it is refused by the server, and earlier orders for it still show it. Given it is the last active district, then the deactivation is refused with a message. |
| AC-37 | FR-24 | Given limit 100, when the owner saves 150, then a date with 120 cakes accepted is available for an order of 30 cakes. |
| AC-38 | FR-24, BR-10 | Given dates 05/11 with 98 cakes and 06/11 with 40 cakes accepted, when the owner enters limit 60, then before saving the owner sees that 05/11 (98 cakes) is above the limit; after saving, both orders on 05/11 remain unchanged, 05/11 shows as full to customers, and 06/11 can take up to 20 more cakes. |
| AC-39 | FR-25 | Given slots 08:00 to 10:00 and 10:00 to 12:00, when the owner adds 14:00 to 16:00, then customers can choose it. When the owner deactivates 08:00 to 10:00, then customers can no longer choose it and earlier orders still show it. |
| AC-40 | FR-25, BR-9, BR-11 | Given a slot with end 09:00 and start 10:00, or a duplicate of an existing slot, then saving is refused with a message. Given the last active slot, then deactivation is refused. |
| AC-41 | FR-26 | Given the owner saves a new greeting and Zalo contact, then the customer shop information shows them at its next refresh. A phone number that is not valid is refused. |
| AC-42 | FR-27 | Given the owner adds "Nhan Vien C" with +84 900 000 003, then that number can request a code (AC-1) and sign in as staff, and the account list shows name, number and role. |
| AC-43 | FR-27, BR-7, BR-8 | Given the number is already on an account, then adding it is refused. Given 10 active staff, then adding an 11th is refused. Given the owner account, then there is no way to deactivate it. A landline or non-Vietnamese number is refused. |
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
| AC-52 | FR-35, BR-15 | Given a device signs out, then a new order sends it no notification and no customer name, phone or address remains readable in the app on that device. Given an account is deactivated, then its devices receive no further notification. |
