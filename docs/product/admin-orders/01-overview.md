# Admin Orders: Overview and Scope (sections 1 to 4)

Part of [Admin Orders](../admin-orders.md) (PRD v1.1). Holds: Summary, Background & Problem, Goals G-1 to G-4, Non-goals, Users & Scenarios, decisions D-1 and D-2. Lines changed in v1.1 end with the label [v1.1 | 2026-10-31].

## 1. Summary

The shop owner and the shop staff sign in on their phones with their e-mail address and a one-time code sent by e-mail, see the orders that customers placed with [Place Order](../place-order.md), and move each order through New, Confirmed, Completed or Cancelled (a cancellation needs a reason). The owner also maintains the shop data that customers see (cakes added, changed or removed; prices; districts; delivery fees; daily limit, lead days and minimum cakes per order; time slots; shop information) and decides who on the staff may sign in. Signed-in devices get a notification when a new order arrives. The admin app is a separate app for iOS and Android, built in the same repository and on the same backend. [v1.1 | 2026-10-31]

## 2. Background & Problem

Customers can place orders today, but nobody on the shop side can see them. Place Order stores each order with status New and left staff features out (see its non-goals). Today the shop values (prices, districts, limit, slots) can only change by a developer. The shop must see new orders quickly, because the customer expects a contact by Zalo or phone after ordering (Place Order A-4). Cancelled orders must give their cakes back to the date, so the shop must be able to cancel.

## 3. Goals / Non-goals

### Goals

- G-1: A staff member sees a newly placed order within 60 seconds of it being stored (push or refresh) and can open it in at most 2 taps from the notification.
- G-2: An order moves New to Confirmed to Completed, or to Cancelled, with 1 action and at most 1 confirmation step (the confirmation step for a cancellation includes choosing a reason); no other status change is possible. [v1.1 | 2026-10-31]
- G-3: The owner can change every shop value listed in FR-22 to FR-26 and FR-38 to FR-40 without a developer, and a change never alters an order already placed (0 existing orders change). [v1.1 | 2026-10-31]
- G-4: A person whose e-mail address the owner has not added gets no access. When the owner removes a staff member or revokes a device, that device loses access to data within 5 minutes and cannot renew its sign-in at once. [v1.1 | 2026-10-31]

### Non-goals

- Payment handling: marking orders paid or unpaid, receipts, refunds. Payment stays outside the app (Place Order A-5).
- Editing an order's items, date, slot, address or customer data. The shop cancels and the customer orders again (Q-10, decided). [v1.1 | 2026-10-31]
- Notifying the customer of status changes by push, SMS or e-mail. The shop contacts the customer by Zalo or phone (Place Order A-4); customers still have no account.
- Changing the image of an existing cake. To change an image, the owner adds a new cake and removes the old one. [v1.1 | 2026-10-31]
- Sending sign-in codes by text message (decided, Q-3). [v1.1 | 2026-10-31]
- Reports, statistics, exports, printing, delivery routing or driver assignment.
- Web admin site, tablet layout, more than one shop.
- Special dates, closed days, per-slot capacity (Place Order BR-10, BR-11 still hold).
- Changing the booking horizon (30 days) (Q-7, decided). [v1.1 | 2026-10-31]
- Reminder notifications for orders left in New (Q-11, decided). [v1.1 | 2026-10-31]
- Showing orders older than 90 days (Q-13, decided). [v1.1 | 2026-10-31]

## 4. Users & Scenarios

| Role | Description |
| ---- | ----------- |
| Owner | One person who runs the shop. Everything staff can do, plus settings, staff management and device management. |
| Staff | A person added by the owner (up to 30). Sees and handles orders only; no settings, no staff list. [v1.1 | 2026-10-31] |
| Customer | Not a user of this feature. Is affected: sees changed prices, cakes, districts and ordering rules, is contacted by the shop. |

Scenarios:

1. New order. A customer orders. Every signed-in staff device shows a notification. A staff member taps it, reads the order, calls the customer, then taps Confirm.
2. Delivery day. Staff open the list, filter by today and Confirmed, deliver, and mark each order Completed.
3. Cancel. The customer asks by Zalo to cancel. Staff open the order, choose the reason "customer asked" and cancel it. The cakes become available again on that date. [v1.1 | 2026-10-31]
4. Change of shop data. The owner adds a new seasonal cake, removes an old one, raises one price and lowers the daily limit for the Tet season. Existing orders keep their price and cake name; new orders use the new values. [v1.1 | 2026-10-31]
5. New helper. The owner adds an e-mail address as staff. That person signs in with a code sent to that address. Later the owner removes the account and the person is signed out. [v1.1 | 2026-10-31]
6. Lost phone. The owner loses the phone, signs in on a new one with codes sent to the owner e-mail and the backup e-mail, then revokes the old device. [v1.1 | 2026-10-31]

## Decisions of the owner

### D-1: Admin inside the customer app, or a separate app (decided, Q-1)

Decision: a separate admin app, built in the same repository and using the same backend. [v1.1 | 2026-10-31]

Reasoning: the customer promise is "no account, no sign-in" (Place Order BR-7); keeping staff features out of that app protects that promise and keeps risk away from the customer release. The customer app declaration stays unchanged; the admin app declares its own. The admin app can be distributed to a small audience only (unlisted on the Apple App Store, S-2). The cost is two more store records and release pipelines, not new business logic, because the backend is shared. [v1.1 | 2026-10-31]

### D-2: iOS and Android, or one platform first (decided, Q-2)

Decision: iOS and Android are built at the same time. [v1.1 | 2026-10-31]

Reasoning: staff may own either kind of phone (Android holds about 60 percent of Vietnamese mobile use, S-4), so no one is excluded. The build and test effort is roughly double that of one platform; the owner accepted this. The backend contract is the same for both. [v1.1 | 2026-10-31]
