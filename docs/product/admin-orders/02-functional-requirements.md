# Admin Orders: Functional Requirements (section 5)

Part of [Admin Orders](../admin-orders.md) (PRD v1.5). Holds: FR-1 to FR-27 (52 before; old ids in [08-deferred-and-id-mapping.md](08-deferred-and-id-mapping.md)). Priority: Must / Should. Values and rules are in [03-business-rules.md](03-business-rules.md); checks in the acceptance criteria parts. Every line is new or changed in v1.5. Items P-1 to P-4 (Q-25 to Q-28) were accepted by the owner on 2026-10-31. [v1.6 | 2026-10-31]

## 5. Functional Requirements

### 5.1 Sign-in and access

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-1 | The system shall let a person enter an e-mail address, receive a 6-digit code by e-mail and sign in with it (BR-4). The screen and response are the same whether or not the address is registered. The person can request a new code after a short wait and can go back to change the address. One code is enough for every account, owner included (Q-18). Limits are in BR-4; when one is reached a Vietnamese message says when to try again. [v1.5 | 2026-10-31] | Must |
| FR-2 | The system shall keep a person signed in on that phone while it is used at least once every 7 days (BR-5) and shall let the person sign out at any time. [v1.5 | 2026-10-31] | Must |
| FR-3 | The system shall give each account one role, owner or staff (BR-1), hide what the role may not do and refuse it on the server. [v1.5 | 2026-10-31] | Must |
| FR-4 | Decided P-2 (Q-26, owner 2026-10-31): the system shall let every signed-in person sign out all their other phones with one button; those phones cannot renew their sign-in and lose data access within 5 minutes (BR-5). This replaces the device list and per-device revoke of v1.4. [v1.5 | 2026-10-31] | Must |
| FR-5 | The system shall let the owner add a staff account (name and e-mail), see the list, and switch an account off or on. Switching off signs out all phones of that person (cannot renew at once, no data within 5 minutes). Limits in BR-6. [v1.5 | 2026-10-31] | Must |
| FR-6 | Invisible: the system shall protect sign-in as in BR-4 and BR-5 (code and request limits, renewal that works once, a repeat within 20 seconds tolerated, nothing revealing which addresses exist). [v1.5 | 2026-10-31] | Must |
| FR-7 | Invisible: when the owner signs in with a code on a phone not used by the owner before, the system shall send one short notice without a code to the owner e-mail (BR-13, Q-24). A failed notice never blocks sign-in. [v1.5 | 2026-10-31] | Must |
| FR-8 | The system shall provide a store-review staff account with a fixed code that sees only fake demo orders (BR-14, Q-19). [v1.5 | 2026-10-31] | Must |

### 5.2 Order list

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-9 | The system shall show orders as a list. Default list "To do": all New and Confirmed orders of any date, ordered by BR-9. A row shows code, customer name, status, delivery date and slot, number of cakes, total and district, and a red "due today" or "overdue N days" mark when the delivery date is today or earlier. [v1.5 | 2026-10-31] | Must |
| FR-10 | The system shall let the person narrow the list by one status (To do, New, Confirmed, Completed, Cancelled, All) and by delivery date (any, today, tomorrow, one chosen date). [v1.5 | 2026-10-31] | Must |
| FR-11 | The system shall let the person search by order code, customer name or phone number (BR-10). [v1.5 | 2026-10-31] | Should |
| FR-12 | The system shall refresh the list when the screen opens and on pull-down, and show loading, empty, offline and error-with-retry states in Vietnamese. [v1.5 | 2026-10-31] | Must |
| FR-13 | The system shall show on the Orders tab a red round number of unfinished orders (New or Confirmed, delivery date today or earlier, BR-9), hidden at 0, "99+" above 99, refreshed with the list and after each status change (Q-22: badge kept; the separate view, chip and banner are dropped, P-3, Q-27, owner 2026-10-31). [v1.5 | 2026-10-31] | Must |

### 5.3 Order detail and status

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-14 | The system shall show for one order: code, status, placed time, customer name, phone, address, district, delivery date and slot, each cake with quantity, price and line total, delivery fee, total, the customer's note, the cancel reason if cancelled, and one line "last changed by <name>, <time>". [v1.5 | 2026-10-31] | Must |
| FR-15 | The system shall offer one-tap Call and Zalo to the customer's number. [v1.5 | 2026-10-31] | Must |
| FR-16 | The system shall let staff and owner change New to Confirmed, with no confirmation step. [v1.5 | 2026-10-31] | Must |
| FR-17 | The system shall let staff and owner change Confirmed to Completed at any time after Confirmed (Q-8), after one confirmation naming the order code. [v1.5 | 2026-10-31] | Must |
| FR-18 | The system shall let staff and owner cancel a New or Confirmed order in one step that requires one reason from BR-8 and a confirmation naming the order code. Cancelling returns the cakes to the delivery date (BR-2). [v1.5 | 2026-10-31] | Must |
| FR-19 | The system shall refuse a change that BR-2 does not allow or that was made on an out-of-date view, keep the order unchanged and show its current status in Vietnamese. Repeating the change an order already has (double tap, retry, a second person) is not an error: same result, no second record, cakes returned once, first cancel reason kept. [v1.5 | 2026-10-31] | Must |

### 5.4 Owner settings (one Settings area, five entries)

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-20 | The system shall show Settings to the owner only, as one list of five entries: Cakes, Ordering, Delivery, Shop info, Staff (FR-5). Staff see neither the entries nor can call them. [v1.5 | 2026-10-31] | Must |
| FR-21 | Cakes: the owner can change a cake's name, description, price, hide it or show it, add a cake (name, description, price, one image) and remove a cake after a confirmation naming it (BR-12). The image of an existing cake cannot be changed. [v1.5 | 2026-10-31] | Must |
| FR-22 | Ordering: the owner can change the daily limit of cakes, days of notice (lead days) and minimum cakes per order (BR-11). Before saving a lower daily limit the owner is told which dates are already above it. [v1.5 | 2026-10-31] | Must |
| FR-23 | Delivery: the owner can add a district, change its name and fee, switch it on or off, and add a time slot, change its times, switch it on or off (BR-11). [v1.5 | 2026-10-31] | Must |
| FR-24 | Shop info: the owner can change shop name, greeting, contact phone and Zalo contact shown to customers (BR-11). [v1.5 | 2026-10-31] | Must |

### 5.5 Notifications and cross-feature

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-25 | The system shall send a notification to every phone of an active signed-in account that allowed notifications when an order is stored; it stops after sign-out, sign-out of other phones or switch-off. No reminders (Q-11). The app works fully when notifications are not allowed. [v1.5 | 2026-10-31] | Must |
| FR-26 | The notification shows order code, number of cakes and delivery date only (no name, phone, address, note) and opens that order when tapped (after sign-in if needed). [v1.5 | 2026-10-31] | Must |
| FR-27 | The system shall not count a cancelled order toward the Place Order limit of 5 orders per phone per 24 hours, except one cancelled as "fake or spam" (Q-12, BR-8). [v1.5 | 2026-10-31] | Must |
