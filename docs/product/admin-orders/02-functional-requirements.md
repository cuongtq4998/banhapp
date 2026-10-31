# Admin Orders: Functional Requirements (section 5)

Part of [Admin Orders](../admin-orders.md) (PRD v1.0). Holds: FR-1 to FR-35. Priority: Must / Should / Could. Rules and values are in [03-business-rules.md](03-business-rules.md); checks are in the acceptance criteria parts.

## 5. Functional Requirements

### 5.1 Sign-in and roles

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-1 | The system shall let a person enter a phone number and request a one-time code, which is sent to that number only if the number belongs to an active owner or staff account. The response shall be the same whether or not the number is registered. | Must |
| FR-2 | The system shall sign a person in when the person enters the correct, unexpired code for the number (BR-5). | Must |
| FR-3 | The system shall let the person request a new code after the wait in BR-5 and shall let the person go back and change the number. | Must |
| FR-4 | The system shall keep a person signed in on that device for the period in BR-6 and shall let the person sign out at any time. | Must |
| FR-5 | The system shall give each account one role, owner or staff, and shall refuse every action outside the role's rights (BR-1) on the server, not only hide it in the app. | Must |
| FR-6 | The system shall limit wrong codes and code requests as in BR-5, and shall tell the person in Vietnamese when a limit is reached and when to try again. | Must |
| FR-7 | The system shall end the sessions of a staff member on every device when the owner deactivates that account (BR-8). | Must |

### 5.2 Order list

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-8 | The system shall show the orders of the shop as a list. Each row shows the order code, customer name, status, delivery date and slot, number of cakes, total and district. By default the list shows New and Confirmed orders in the order of BR-13. | Must |
| FR-9 | The system shall let the person filter the list by status: one or more of New, Confirmed, Completed, Cancelled, or all. | Must |
| FR-10 | The system shall let the person filter the list by delivery date: today, tomorrow, one chosen date, or a chosen range. | Must |
| FR-11 | The system shall let the person search by order code, part of the customer name, or part of the phone number. | Should |
| FR-12 | The system shall show the number of orders in New, update the list when the screen opens and on pull-to-refresh, and show when the list was last updated. | Must |
| FR-13 | The system shall show an empty state (no orders match), a loading state, an offline state and an error state with retry, all in Vietnamese. | Must |

### 5.3 Order detail and status changes

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-14 | The system shall show for one order: code, status, placed date and time, customer name, phone, address, district, delivery date and slot, each cake with quantity, unit price and line total, delivery fee, total, and the customer's note if any. | Must |
| FR-15 | The system shall offer one-tap actions to call the customer and to open a Zalo chat with the customer's number. | Should |
| FR-16 | The system shall let staff and owner change an order from New to Confirmed. | Must |
| FR-17 | The system shall let staff and owner change an order from Confirmed to Completed. | Must |
| FR-18 | The system shall let staff and owner change an order from New or Confirmed to Cancelled after an explicit confirmation step that names the order code. Cancelling shall return the order's cakes to its delivery date (BR-3). | Must |
| FR-19 | The system shall refuse a status change that is not allowed (BR-2) or that was made on an out-of-date view of the order (another person changed it first), keep the stored order unchanged, show the order's current status and tell the person in Vietnamese. | Must |
| FR-20 | The system shall show the order's status history: each change with the old status, new status, who made it (name of account or "customer" for creation) and when. | Should |

### 5.4 Owner settings

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-21 | The system shall show the settings area to the owner only. Staff shall see the order tabs only and the server shall refuse settings actions from staff. | Must |
| FR-22 | The system shall let the owner change, for each of the existing cakes, its name, description, price and whether it is active (shown and orderable) or hidden (BR-11). | Must |
| FR-23 | The system shall let the owner add a served district, change a district's name and delivery fee, and activate or deactivate a district. | Must |
| FR-24 | The system shall let the owner change the daily limit of cakes (BR-10 for the effect on booked dates). | Must |
| FR-25 | The system shall let the owner add a delivery time slot, change its start and end time, and activate or deactivate it. | Must |
| FR-26 | The system shall let the owner change the shop name, greeting, contact phone number and Zalo contact shown to customers. | Must |
| FR-27 | The system shall let the owner add a staff account (name and Vietnamese mobile phone number), see the list of accounts, and deactivate or reactivate a staff account. | Must |
| FR-28 | The system shall validate every setting against BR-9, refuse an invalid value with a Vietnamese message that names the field, and save nothing from a refused form. | Must |
| FR-29 | The system shall apply a settings change only to orders placed after it is saved; existing orders keep their prices, fees, district name and slot (Place Order BR-6). | Must |
| FR-30 | The system shall record for every settings change who made it, when, and the old and new value. | Should |

### 5.5 Notifications

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-31 | The system shall send a notification to every device of an active signed-in owner or staff account that allowed notifications, when a customer's order is stored. | Must |
| FR-32 | The notification shall show the order code, number of cakes and delivery date, and shall not contain the customer's name, phone number, address or note. | Must |
| FR-33 | The system shall open the order's detail when the person taps the notification (after sign-in if the session ended). | Should |
| FR-34 | When the person has not allowed notifications on the device, the system shall still work fully and shall show once per sign-in a Vietnamese hint on how to allow them. | Should |
| FR-35 | The system shall stop sending notifications to a device after its user signs out or the account is deactivated. | Must |
