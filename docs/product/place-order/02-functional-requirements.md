# Place Order: Functional Requirements (section 5)

Part of [Place Order](../place-order.md) (PRD v1.4.1). Holds: FR-1 to FR-21. [v1.4.1 | 2026-10-27]

## 5. Functional Requirements

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-1 | The system shall show a logo-only launch screen on app start, then the home screen. | Must |
| FR-2 | The system shall show on the home screen the shop name, a short greeting, a Zalo contact button, a phone contact button, a "View products" button and a "Place order" button. | Must |
| FR-3 | The system shall list the active cakes (1 to 4 are all normal; four at launch), each with picture, name, short description and current price. A cake that is not active (hidden by the shop) is not listed and cannot be ordered. When zero cakes are active the system shall show an Error state instead of a list and shall not let the customer start an order. [v1.4 | 2026-10-26] | Must |
| FR-4 | The system shall show a detail view for each cake with a button that starts an order including that cake at quantity 1. [v1.1 | 2026-10-25] | Must |
| FR-5 | The system shall let the customer choose a quantity per cake for any of the active cakes in one order. [v1.4 | 2026-10-26] | Must |
| FR-6 | The system shall let the customer choose a receiving date; dates that cannot hold the whole order (BR-1), are earlier than the lead time (BR-2) or are later than the booking horizon (BR-8) shall not be selectable. [v1.1 | 2026-10-25] | Must |
| FR-7 | The system shall let the customer choose a receiving time from one fixed list of delivery time slots that is the same for every date. [v1.1 | 2026-10-25] | Must |
| FR-8 | The system shall collect the customer's name, phone number and delivery address, and the district from the served list (BR-3). | Must |
| FR-9 | The system shall show a review of the order before confirmation: cakes, quantities, line prices, delivery fee, total, date, time, name, phone, address and note if entered. [v1.1 | 2026-10-25] | Must |
| FR-10 | The system shall block confirmation and tell the customer the reason in Vietnamese when any ordering rule (BR-1 to BR-4, BR-8) is not met. [v1.1 | 2026-10-25] | Must |
| FR-11 | The system shall, on confirmation, record the order and show only a confirmation screen with a unique order code and a message that the order is received and the shop will contact the customer (not that it is accepted). [v1.1 | 2026-10-25] | Must |
| FR-12 | The system shall show Zalo and phone contact buttons on the confirmation screen. | Should |
| FR-13 | The system shall validate required fields (name, phone, address, district) and show the error next to the field. | Must |
| FR-14 | The system shall show all customer-facing text in Vietnamese. | Must |
| FR-15 | The system shall let the customer return to a previous step in the order flow without losing entered data. | Should |
| FR-16 | The system shall prevent one confirmation tap sequence from creating duplicate orders (repeated taps or retry create at most one order). | Must |
| FR-17 | The system shall show a clear message and keep entered data when the order cannot be sent (no connection or server error). | Must |
| FR-18 | The system shall let the customer enter one optional free-text order note of at most 200 characters and shall keep it with the order. [v1.1 | 2026-10-25] | Should |
| FR-19 | The system shall show no payment information or payment instruction anywhere in the app. [v1.1 | 2026-10-25] | Must |
| FR-20 | The system shall show a privacy notice before the customer enters any data (before the first data entry step, not only at review). The notice shall cover the name, phone number, delivery address, the optional note, and the order draft stored on the customer's device, and shall say why they are collected. No retention period is stated yet (BR-12, 12.1). Pending owner confirmation (12.2). [v1.3 | 2026-10-25] | Must |
| FR-21 | The system shall by default display dates as dd/MM/yyyy and money amounts in whole dong with Vietnamese thousands separators (a dot, for example 120.000), with the unit dong. Pending owner confirmation (12.2). [v1.3 | 2026-10-25] | Must |
