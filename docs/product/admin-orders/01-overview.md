# Admin Orders: Overview and Scope (sections 1 to 4)

Part of [Admin Orders](../admin-orders.md) (PRD v1.0). Holds: Summary, Background & Problem, Goals G-1 to G-4, Non-goals, Users & Scenarios, decisions D-1 and D-2.

## 1. Summary

The shop owner and the shop staff sign in on their phones with their phone number and a one-time code, see the orders that customers placed with [Place Order](../place-order.md), and move each order through New, Confirmed, Completed or Cancelled. The owner also maintains the shop data that customers see (cakes, prices, districts, delivery fees, daily limit, time slots, shop information) and decides who on the staff may sign in. Signed-in devices get a notification when a new order arrives.

## 2. Background & Problem

Customers can place orders today, but nobody on the shop side can see them. Place Order stores each order with status New and left staff features out (see its non-goals). Today the shop values (prices, districts, limit, slots) can only change by a developer. The shop must see new orders quickly, because the customer expects a contact by Zalo or phone after ordering (Place Order A-4). Cancelled orders must give their cakes back to the date, so the shop must be able to cancel.

## 3. Goals / Non-goals

### Goals

- G-1: A staff member sees a newly placed order within 60 seconds of it being stored (push or refresh) and can open it in at most 2 taps from the notification.
- G-2: An order moves New to Confirmed to Completed, or to Cancelled, with 1 action and at most 1 confirmation step; no other status change is possible.
- G-3: The owner can change every shop value listed in FR-22 to FR-26 without a developer, and a change never alters an order already placed (0 existing orders change).
- G-4: A person whose number the owner has not added gets no access, and removing a staff member ends that person's access within 1 minute.

### Non-goals

- Payment handling: marking orders paid or unpaid, receipts, refunds. Payment stays outside the app (Place Order A-5).
- Editing an order's items, date, slot, address or customer data. The shop cancels and the customer orders again (Q-10).
- Notifying the customer of status changes by push, SMS or e-mail. The shop contacts the customer by Zalo or phone (Place Order A-4); customers still have no account.
- Adding or deleting cakes, or uploading cake photos. The owner edits and hides the existing cakes (Q-6).
- Reports, statistics, exports, printing, delivery routing or driver assignment.
- Web admin site, tablet layout, more than one shop.
- Special dates, closed days, per-slot capacity (Place Order BR-10, BR-11 still hold).
- Changing lead days, minimum quantity or booking horizon (Q-7).
- Reminder notifications for orders left in New (Q-11).

## 4. Users & Scenarios

| Role | Description |
| ---- | ----------- |
| Owner | One person who runs the shop. Everything staff can do, plus settings and staff management. |
| Staff | A person added by the owner. Sees and handles orders only; no settings, no staff list. |
| Customer | Not a user of this feature. Is affected: sees changed prices and districts, is contacted by the shop. |

Scenarios:

1. New order. A customer orders. Every signed-in staff device shows a notification. A staff member taps it, reads the order, calls the customer, then taps Confirm.
2. Delivery day. Staff open the list, filter by today and Confirmed, deliver, and mark each order Completed.
3. Cancel. The customer asks by Zalo to cancel. Staff open the order and cancel it. The cakes become available again on that date.
4. Change of shop data. The owner raises the price of one cake and lowers the daily limit for the Tet season. Existing orders keep their price; new orders use the new price.
5. New helper. The owner adds a phone number as staff. That person signs in with a code sent to the number. Later the owner removes the number and the person is signed out.

## Decisions for the owner (recommended)

### D-1: Admin inside the customer app, or a separate app

Recommendation: a separate admin app, built in the same repository and using the same backend. Final choice is the owner's (Q-1).

| Aspect | Inside the customer app (role-gated) | Separate admin app (recommended) |
| ------ | ------------------------------------ | -------------------------------- |
| Customer experience | Staff login entry exists in a consumer app; extra screens and a notification permission prompt that customers never need | Customer app stays anonymous, no login, unchanged |
| Store privacy declaration | Customer app would also declare phone-number sign-in and notifications | Customer app declaration stays as is; admin app declares its own |
| Review and security | Admin code ships to every customer; Apple asks reviewers to be able to use every feature (needs a demo account, S-3) | Admin app can be distributed to a small audience only (unlisted on the Apple App Store, S-2) |
| Cost and effort | One app, one release | Two more store records and release pipelines, about one extra project per platform |
| Reversibility | Splitting out later is a migration of users and store records | Merging later is a rebuild |

Reasoning: the customer promise is "no account, no sign-in" (Place Order BR-7); keeping staff features out of that app protects that promise and keeps risk away from the customer release. The extra cost is store setup and build pipeline, not new business logic, because the backend is shared.

### D-2: iOS and Android, or one platform first

Recommendation: one platform first, the platform of the owner's and staff's own phones; the second platform follows only if some staff need it (Q-2). If the owner has no preference, Android first, because it holds about 60 percent of Vietnamese mobile use (S-4).

Reasoning: the audience is a handful of people whose phones the owner knows. Two platforms double the build and test effort for a user group that can be asked to use one. The customer app needs both because its audience is the public; this one does not. The backend contract is the same for both, so adding the second platform later costs only the app itself.
