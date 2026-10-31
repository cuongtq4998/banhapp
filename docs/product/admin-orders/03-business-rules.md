# Admin Orders: Business Rules (section 6)

Part of [Admin Orders](../admin-orders.md) (PRD v1.0). Holds: BR-1 to BR-15. Values marked "proposed" are defaults the owner may change (see [07-open-questions.md](07-open-questions.md)). Place Order rules (BR-1 to BR-13 there) are cited as "PO BR-n".

## 6. Business Rules

| ID | Rule |
| -- | ---- |
| BR-1 | Rights. Owner: everything. Staff: sign in and out, list, search, filter and open orders, confirm, complete and cancel orders, receive notifications. Only the owner: settings (FR-22 to FR-26) and staff management (FR-27). Neither role can edit an order's content, delete an order, or see payment data. |
| BR-2 | Allowed status changes, and no others: New to Confirmed, New to Cancelled, Confirmed to Completed, Confirmed to Cancelled. Completed and Cancelled are final: no change out of them, no reopening. This follows the lifecycle already enforced by the database (docs/system/order-lifecycle.md section 6). |
| BR-3 | Cancelling an order returns its cakes to the remaining amount of its delivery date at once (PO BR-9). Confirming or completing changes no capacity. |
| BR-4 | Every status change records who made it and when. The record cannot be edited or deleted. |
| BR-5 | One-time code: 6 digits, valid 5 minutes, usable once; a new code makes the old one invalid. A new code can be requested 30 seconds after the previous one (the reference design shows 30 s). At most 3 codes per phone number per hour. After 5 wrong codes for one number the number is locked for 15 minutes. All values proposed. |
| BR-6 | A sign-in stays valid for 30 days on that device, then a new code is needed (proposed, Q-4). Signing out ends it at once on that device. |
| BR-7 | Only a Vietnamese mobile number that the owner added can sign in; the format is the one used for customers (docs/system/data-model, ADR-0009). A number belongs to one account. |
| BR-8 | Accounts: exactly one owner and up to 10 active staff (proposed, Q-5). The owner cannot deactivate or delete the owner account. A deactivated staff account keeps its name in the status history of earlier orders. Deactivation takes effect within 1 minute on every device. |
| BR-9 | Setting limits. Cake price: whole dong, 1 to 100 000 000. Delivery fee: whole dong, at least 1 (PO BR-3, no free delivery), at most 10 000 000. Daily limit: whole number from 1 to 9 999. Slot: start earlier than end, no two slots with the same start and end, same list on every date (PO BR-10, BR-11). Name and description lengths: as in docs/system/data-model section 3 (name 1 to 100, description 1 to 300, greeting 1 to 300, district name 1 to 100, unique). Contact phone: valid phone number; Zalo: as the customer app uses it. All fields are required. |
| BR-10 | Lowering the daily limit below the cakes already accepted for a date cancels nothing: the existing orders stay, that date shows as full to customers, and cancelling orders on it frees room again. Before saving, the owner is told which dates are already above the new limit (count and dates). Raising the limit makes room at once. |
| BR-11 | The shop sells at most four cakes (PO non-goal). The owner can hide a cake but not add or delete one. The last active cake cannot be hidden (PO BR-13 treats zero active cakes as an error state of the customer app). Likewise the last active district and the last active slot cannot be deactivated. |
| BR-12 | Price and fee changes follow PO BR-5 and BR-6: a customer who has an order open on the review step with the old price is asked to confirm the new total (PO behaviour "price changed"); stored orders never change. Hidden cakes, deactivated districts and slots disappear from the customer app at its next refresh and are refused by the server at once. |
| BR-13 | List order and size. Default list: New and Confirmed orders, earliest delivery date first, then earliest slot, then oldest placed first. With status Completed or Cancelled in the filter, the same order applies. The list loads 50 orders at a time and loads the next 50 when the person reaches the end. |
| BR-14 | Notification content and reach: see FR-31, FR-32. The notification is a prompt, not the record: the list is always the source of truth, and an order whose notification was lost is still in the list. |
| BR-15 | Customer data in the admin app is visible only to a signed-in active account, is not written to the notification text, logs or analytics, and is removed from the device when the person signs out. Retention of the stored data follows PO BR-12 (period still pending, PO Q-O4). |
