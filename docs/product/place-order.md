# Place Order

| Field        | Value                                                        |
| ------------ | ------------------------------------------------------------ |
| Version      | 1.0                                                          |
| Last updated | 2026-10-25                                                   |
| Status       | Draft                                                        |
| Owner        | scribe-requirements                                          |
| Based on     | docs/pipeline/place-order/00-request.md (2026-10-25)         |
| Related      | UI mockups (reference only): https://claude.ai/artifact/HcWoUjBbqA9B1WUvZ3RKCb |

## 1. Summary

A customer of a small banh tet pre-order shop uses a mobile app (iOS and Android) to browse four cakes and place an order for delivery on a chosen date and time. No account is needed. The app ends with a confirmation screen showing an order code; all later contact happens by Zalo or phone.

## 2. Background & Problem

The shop sells traditional Vietnamese sticky-rice cakes (banh tet) on pre-order and can make only a limited number per day. Orders must arrive in a form the shop can plan around: enough lead time, within daily capacity, to a served district, and with a worthwhile quantity. Customers need a simple way to see the products and order without registering. This is the first slice; shop-side order handling is a later feature.

## 3. Goals / Non-goals

### Goals

- G-1: A customer can go from app launch to a confirmed order in at most 6 steps after tapping "Place order" (cakes, date and time, address, review, confirm) without creating an account.
- G-2: No accepted order breaks any ordering rule (BR-1 to BR-4): 0 orders accepted that exceed the daily limit, violate lead time, target an unserved district or fall below the minimum quantity.
- G-3: Every confirmed order gets an order code that the customer can quote to the shop.

### Non-goals

- Online payment (undecided; see Q-9).
- Order tracking, status display or cancellation in the app.
- Customer accounts, login, order history.
- Staff and owner features: login by phone with one-time code, order list and statuses (New, Confirmed, Completed, Cancelled), owner configuration of products, prices, districts and fees, daily limit, time slots, shop information, staff; push notifications.
- Pickup at the shop (only delivery to the door is requested).
- More than the four products, or product variations.

## 4. Users & Scenarios

| Role | Description |
| ---- | ----------- |
| Customer | Anyone ordering cakes; identified only by name, phone number and address. |
| Shop owner / staff | Not a user of this feature. Receives the orders in a later feature; affected by the rules. |

Scenarios:

1. Browse then order. The customer opens the app, taps "View products", reads a cake detail, taps the order button there, and completes an order.
2. Direct order. The customer taps "Place order" on the home screen, chooses cakes, date, time, enters address, reviews and confirms.
3. Blocked choice. The customer tries a date that is full, too soon, or an unserved district and is told why and can change the choice.

## 5. Functional Requirements

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-1 | The system shall show a logo-only launch screen on app start, then the home screen. | Must |
| FR-2 | The system shall show on the home screen the shop name, a short greeting, a Zalo contact button, a phone contact button, a "View products" button and a "Place order" button. | Must |
| FR-3 | The system shall list the four cakes, each with picture, name, short description and current price. | Must |
| FR-4 | The system shall show a detail view for each cake with a button that starts an order including that cake. | Must |
| FR-5 | The system shall let the customer choose a quantity per cake for any of the four cakes in one order. | Must |
| FR-6 | The system shall let the customer choose a receiving date; dates that are full (BR-1) or earlier than the lead time (BR-2) shall not be selectable. | Must |
| FR-7 | The system shall let the customer choose a receiving time from the shop's delivery time slots. | Must |
| FR-8 | The system shall collect the customer's name, phone number and delivery address, and the district from the served list (BR-3). | Must |
| FR-9 | The system shall show a review of the order before confirmation: cakes, quantities, line prices, delivery fee, total, date, time, name, phone and address. | Must |
| FR-10 | The system shall block confirmation and tell the customer the reason in Vietnamese when any ordering rule (BR-1 to BR-4) is not met. | Must |
| FR-11 | The system shall, on confirmation, record the order and show only a confirmation screen with a unique order code. | Must |
| FR-12 | The system shall show Zalo and phone contact buttons on the confirmation screen. | Should |
| FR-13 | The system shall validate required fields (name, phone, address, district) and show the error next to the field. | Must |
| FR-14 | The system shall show all customer-facing text in Vietnamese. | Must |
| FR-15 | The system shall let the customer return to a previous step in the order flow without losing entered data. | Should |
| FR-16 | The system shall prevent one confirmation tap sequence from creating duplicate orders (repeated taps or retry create at most one order). | Must |
| FR-17 | The system shall show a clear message and keep entered data when the order cannot be sent (no connection or server error). | Must |

## 6. Business Rules

All values are shop parameters (not yet provided; see Open Questions). The system shall read them as configuration, not as fixed values in the requirements.

| ID | Rule |
| -- | ---- |
| BR-1 | Daily limit: the total number of cakes accepted for one receiving date shall not exceed DAILY_LIMIT. A date where the limit is reached cannot be chosen. An order that would push a date over the limit shall not be accepted (see Q-2 for counting scope and partial availability). |
| BR-2 | Lead time: the receiving date shall be at least LEAD_DAYS (N) days after the order date. How a day is counted is Q-4. |
| BR-3 | Delivery area: delivery is only to districts on the served list. The delivery fee is the fee of the district chosen. |
| BR-4 | Minimum quantity: the total number of cakes in one order shall be at least MIN_QTY. |
| BR-5 | Order total = sum of (current price x quantity) for each cake + delivery fee. Prices are those shown at the time of review. Currency and rounding: Q-8. |
| BR-6 | Prices may change; an order keeps the prices shown to the customer at confirmation. |
| BR-7 | Identity: no account. An order is identified by its order code and holds the name, phone number and address given. |

## 7. Acceptance Criteria

Parameter names (LEAD_DAYS, DAILY_LIMIT, MIN_QTY) stand for the shop's values; test data uses fake values agreed at test time.

| ID | Checks | Given / When / Then |
| -- | ------ | ------------------- |
| AC-1 | FR-1 | Given the app is installed, when it is opened, then a screen with only the logo appears, then the home screen. |
| AC-2 | FR-2 | Given the home screen, then shop name, greeting, Zalo button, phone button, "View products" and "Place order" are visible. |
| AC-3 | FR-2 | Given the home screen, when the Zalo or phone button is tapped, then the device opens Zalo or the phone dialer with the shop's number. |
| AC-4 | FR-3 | Given "View products" is tapped, then exactly four cakes are listed, each with picture, name, description and price. |
| AC-5 | FR-4 | Given a cake detail, when its order button is tapped, then the order flow opens with that cake at quantity 1 (default, see Q-13). |
| AC-6 | FR-5 | Given the cake step, when quantities 2, 0, 3, 0 are entered, then the review lists only the two cakes with quantity above 0. |
| AC-7 | FR-6, BR-2 | Given today is D and LEAD_DAYS is N, when the date picker opens, then no date earlier than D+N can be selected. |
| AC-8 | FR-6, BR-1 | Given a date already holds DAILY_LIMIT cakes, when the date picker opens, then that date cannot be selected. |
| AC-9 | FR-10, BR-1 | Given a date has R cakes remaining and the order has more than R cakes, when the customer tries to proceed, then the order is not confirmed and the message states the rule broken. |
| AC-10 | FR-7 | Given a date is chosen, then only the shop's time slots are offered and one must be chosen to proceed. |
| AC-11 | FR-8, BR-3 | Given the address step, when a district is chosen, then the delivery fee for that district is shown; a district not on the list cannot be chosen. |
| AC-12 | FR-13 | Given a required field is empty or the phone number is not a valid number, when the customer proceeds, then an error appears next to the field and the flow does not advance. |
| AC-13 | FR-10, BR-4 | Given total quantity is below MIN_QTY, when the customer tries to confirm, then confirmation is blocked and the minimum is stated. |
| AC-14 | FR-9, BR-5 | Given 2 of cake A at price a, 1 of cake B at price b and district fee f, when the review is shown, then the total equals 2a + b + f. |
| AC-15 | FR-11, BR-7 | Given a valid order, when the customer confirms, then only a confirmation screen with an order code appears, with no tracking or cancel option, and the order is stored with the entered name, phone and address. |
| AC-16 | FR-11 | Given two confirmed orders, then their order codes differ. |
| AC-17 | FR-12 | Given the confirmation screen, then Zalo and phone buttons are visible and work as in AC-3. |
| AC-18 | FR-15 | Given the customer is on the review step with data entered, when going back to the cake step and forward again, then all entered data is still present. |
| AC-19 | FR-16 | Given the confirm button is tapped twice quickly or retried after a timeout, then at most one order exists for it. |
| AC-20 | FR-17 | Given the device has no connection, when the customer confirms, then no confirmation screen appears, a message says the order was not sent, and entered data is kept. |
| AC-21 | FR-14 | Given any screen or error message, then its text is in Vietnamese. |
| AC-22 | BR-1 | Given two customers confirm at the same time when only enough capacity remains for one, then exactly one order is accepted and the other is told the date is no longer available. |
| AC-23 | BR-6 | Given a price changes after an order was confirmed, then the confirmed order still shows the price at confirmation. |

## 8. Non-functional

- Language: Vietnamese for all customer text.
- Platforms: iOS and Android phones. Look and feel is native: Liquid Glass on iOS, Material 3 Expressive on Android (design-level; minimum OS versions are Q-T3).
- Privacy: the app collects name, phone number and address. It shall tell the customer what is collected and why before confirmation, and shall not collect more than the order needs. Store listings require a privacy disclosure (Q-T4). Apple's guideline requires that apps not force sign-in unless account features need it, which matches the no-account decision (source S-2).
- Accessibility: text scales with the system font size; every control has a text label for screen readers; contrast meets WCAG 2.2 AA (4.5:1 for body text). Reasoning: public consumer app, store expectations (unverified as a store requirement).
- Performance: the order submission shall give the customer a result (confirmation or error) within 10 seconds on a normal mobile connection, otherwise show an error (FR-17). Target value proposed; owner may adjust.
- Cost: low running cost for a small shop (constraint, no number given; see Q-T5).

## 9. Impact & Dependencies

- Staff and owner features (later): will read the orders created here and supply the values for products, prices, districts, fees, daily limit and slots. Until they exist, those values must come from another source (Q-T2).
- Daily limit counting depends on how later cancellations affect capacity (Q-2, Q-12).
- Payment feature (later, undecided): this slice must not collect payment details.
- Design canvas mockups: reference only; this document is authoritative.
- External apps: Zalo and the device phone dialer.

## 10. Assumptions

- A-1: Shop timezone is Vietnam (UTC+7); all dates and times are in it.
- A-2: One order has one delivery date, time and address.
- A-3: The daily limit counts all cakes of all four products together (Q-2 asks to confirm).
- A-4: Orders are binding requests; the shop contacts or is contacted via Zalo/phone afterwards. The confirmation screen should not promise acceptance beyond "order received" until the owner answers Q-7.
- A-5: Payment is settled outside the app (e.g. on delivery) until decided.
- A-6: Customers are in Vietnam; phone numbers are Vietnamese format (validation rule is Q-T6).
- A-7: Sample and test data are fake.

## 11. Research & Sources

| ID | Claim | Source (URL) | Read on | Confidence |
| -- | ----- | ------------ | ------- | ---------- |
| S-1 | Bakeries typically set lead times of about 24-72 hours for standard and custom items, longer for large custom orders; a firm daily cut-off time (often evening or early afternoon) is used for planning, and weekend limits are suggested to prevent overbooking. This informs Q-1, Q-2, Q-4. | https://roseperl.com/?p=22183 ; https://support.breadltd.co.uk/hc/en-us/articles/4415109505810-What-are-your-order-cut-off-times ; https://findhomegrown.com/blog/order-cutoff-times-food-business | 2026-10-25 | Low to medium (vendor and shop pages, no authoritative standard) |
| S-2 | Apple App Review Guideline 5.1.1: apps should not require sign-in or personal data unless relevant to core functionality; checkout may need identity details. Taken from forum quotations, not the guideline page. | https://developer.apple.com/forums/thread/835254 | 2026-10-25 | Low (secondhand; verify on the official guideline page) |
| S-3 | Google Play Data safety requirements: not found in research. | not found | 2026-10-25 | Unverified |

## 12. Open Questions

Business questions are for the product owner; technical questions are for the architect (atlas-architect). Recommended defaults are suggestions only, not decisions.

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-1 | What is N, the minimum lead days between ordering and receiving? Default proposed: 2 days (S-1: 48 hours is common for baked goods that need preparation). | BR-2, AC-7. | Yes | business | Open | |
| Q-2 | What is the daily cake limit, and does it count all four cakes together or per cake? Default proposed: one shared total. When a date has fewer cakes left than the customer wants, show the date as selectable only if the remaining amount covers the order (default), or let them reduce the order? | BR-1, AC-8, AC-9. | Yes | business | Open | |
| Q-3 | What is the minimum total quantity per order? Default proposed: 2 cakes, to be confirmed by delivery cost. Also: is there a maximum per order? | BR-4, AC-13. | Yes | business | Open | |
| Q-4 | How is lead time counted: whole days from the order date, or is there a daily cut-off time (e.g. orders after 18:00 count as the next day)? Default proposed: calendar days, no cut-off, simplest (S-1 shows cut-offs are common). | BR-2 edge cases. | No | business | Open | |
| Q-5 | Which districts are served and what is the fee for each? Is delivery ever free above some amount? Default proposed: flat fee per district, no free delivery. | BR-3, AC-11, BR-5. | Yes | business | Open | |
| Q-6 | Which delivery time slots exist (e.g. morning, afternoon) or can the customer pick any time? Do slots differ by weekday, and do slots have their own capacity? Default proposed: a short fixed list of slots, same every day, capacity only per day. | FR-7, AC-10. | Yes | business | Open | |
| Q-7 | After confirming, is the order a request the shop may still decline (so wording says "received" rather than "accepted")? Default proposed: wording "order received, the shop will contact you". | Confirmation text, expectation of customers. | No | business | Open | |
| Q-8 | What are the four cake prices (and currency/rounding in VND), and shop name, greeting, Zalo and phone contacts? Default proposed: placeholders marked as sample data until provided. | FR-2, FR-3, BR-5. | Yes (to ship; not to design) | business | Open | |
| Q-9 | How does the customer pay in this period (cash on delivery, bank transfer on request)? Should the app display a payment note? Default proposed: show a short note "pay on delivery" only if the owner confirms; otherwise no payment text. | Customer expectation; deposit rules may affect the daily limit. | No | business | Open | |
| Q-10 | How far ahead may a customer order (maximum days ahead)? Default proposed: 30 days. | Date picker range. | No | business | Open | |
| Q-11 | Are there special dates (e.g. Tet, when demand is very high) with different limits, lead times or closed days? Default proposed: out of this slice; rules apply uniformly, closed days handled later by owner configuration. | Date availability. | No | business | Open | |
| Q-12 | When staff later cancel an order, should its cakes return to the daily limit? Default proposed: yes. | BR-1 correctness over time. | No | business | Open | |
| Q-13 | Can the customer add a note (e.g. delivery instructions, gift message)? Default quantity when starting from a cake detail: 1. Default proposed: one optional free-text note, 200 characters max. | FR-8, AC-5. | No | business | Open | |
| Q-14 | Is the customer's contact data kept for how long, and who may see it? Default proposed: kept as long as the shop needs for fulfilment; owner states a period. | Privacy notice text. | No | business | Open | |
| Q-T1 | How is the daily limit enforced so that two simultaneous orders cannot both exceed it (AC-22), and how is a duplicate submission detected (AC-19)? | FR-16, BR-1. | No | technical | Open (architect) | |
| Q-T2 | Until owner configuration exists, where do products, prices, districts, fees, limits and slots come from, and how will later staff features take them over without changing this slice? | Dependency on later features. | No | technical | Open (architect) | |
| Q-T3 | Which minimum iOS and Android versions are targeted, given Liquid Glass and Material 3 Expressive availability? | Native look vs reach. | No | technical | Open (architect) | |
| Q-T4 | What privacy disclosures do the App Store and Google Play require for collecting name, phone and address (S-3 unverified)? | Store approval. | No | technical | Open (architect) | |
| Q-T5 | What hosting and running-cost ceiling fits a small shop? | Constraint "low cost". | No | technical | Open (architect) | |
| Q-T6 | Phone number validation rules (Vietnamese formats, international numbers allowed?) and order code format (readable, not guessable)? | FR-8, FR-11. | No | technical | Open (architect) | |

## 13. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version (Draft). |
