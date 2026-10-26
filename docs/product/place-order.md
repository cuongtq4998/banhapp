# Place Order

| Field        | Value                                                        |
| ------------ | ------------------------------------------------------------ |
| Version      | 1.3                                                          |
| Last updated | 2026-10-25                                                   |
| Status       | Approved [v1.2 | 2026-10-25]. v1.3 clarifies wording only; no owner-decided number or rule changed. Items under "Added in v1.3, pending owner confirmation" (12.2) do not take effect until the owner confirms. [v1.3 | 2026-10-25] |
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
- G-2: No accepted order breaks any ordering rule (BR-1 to BR-4, BR-8): 0 orders accepted that exceed the daily limit, violate lead time or the 30-day horizon, target an unserved district or fall below the minimum quantity. [v1.1 | 2026-10-25]
- G-3: Every confirmed order gets an order code that the customer can quote to the shop.

### Non-goals

- Online payment and any payment text in the app; payment happens outside the app (Q-9, answered). [v1.1 | 2026-10-25]
- Order tracking, status display or cancellation in the app.
- Customer accounts, login, order history.
- Staff and owner features: login by phone with one-time code, order list and statuses (New, Confirmed, Completed, Cancelled), owner configuration of products, prices, districts and fees, daily limit, time slots, shop information, staff; push notifications.
- Pickup at the shop (only delivery to the door is requested).
- More than the four products, or product variations.
- Special dates (e.g. Tet) with different limits, lead times or closed days: rules apply uniformly in this slice (Q-11). [v1.1 | 2026-10-25]
- Free delivery or delivery fee discounts. [v1.1 | 2026-10-25]

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
| FR-4 | The system shall show a detail view for each cake with a button that starts an order including that cake at quantity 1. [v1.1 | 2026-10-25] | Must |
| FR-5 | The system shall let the customer choose a quantity per cake for any of the four cakes in one order. | Must |
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

## 6. Business Rules

All numeric and list values are shop parameters. The system shall read them as configuration, not as fixed values in the requirements. Values already decided are stated here; values the shop must still supply are in "Launch data to be provided by the shop" (section 12.1). [v1.1 | 2026-10-25]

| ID | Rule |
| -- | ---- |
| BR-1 | Daily limit: one shared total of cakes of all four products per receiving date shall not exceed DAILY_LIMIT. A date is selectable only if its remaining amount (DAILY_LIMIT minus cakes already accepted for that date) is at least the total number of cakes in the order. An order that would push a date over the limit shall not be accepted. A cancelled order returns its cakes to the date's remaining amount (BR-9). The value of DAILY_LIMIT is provided by the shop. [v1.1 | 2026-10-25] |
| BR-2 | Lead time: the receiving date shall be at least LEAD_DAYS calendar days after the order date; LEAD_DAYS is 2. Days are counted in calendar days with no daily cut-off time: an order placed at any time on day D can be received from D+2. The order date D is the server's current date in the shop time zone (A-1, A-8), never the device clock or device time zone. Tests set a controllable server clock; with the same server date, any time from 00:00:00 to 23:59:59 gives the same result, and the result changes at midnight shop time. [v1.3 | 2026-10-25] |
| BR-3 | Delivery area: delivery is only to districts on the served list. The delivery fee is the flat fee of the district chosen; there is no free delivery. The district list and fees are provided by the shop. [v1.1 | 2026-10-25] |
| BR-4 | Minimum quantity: the total number of cakes in one order shall be at least MIN_QTY; MIN_QTY is 2. There is no maximum per order other than the remaining amount of the chosen date (BR-1). Separately, as a technical input-safety bound that is not a business maximum, the app and server accept 1 to 99 of one cake in a line (ADR-0009, configuration key max_qty_per_cake); a line above 99 is rejected as invalid input, and the shop can raise the bound in configuration. [v1.3 | 2026-10-25] |
| BR-5 | Order total = sum of (current price x quantity) for each cake + delivery fee. Prices are those shown at the time of review. Currency is Vietnamese dong (VND), amounts in whole dong (confirmed by the owner; no rounding is needed). [v1.2 | 2026-10-25] |
| BR-6 | Prices may change; an order keeps the prices shown to the customer at confirmation. |
| BR-7 | Identity: no account. An order is identified by its order code and holds the name, phone number, address and note given. [v1.1 | 2026-10-25] |
| BR-8 | Booking horizon: the receiving date shall be no more than MAX_DAYS_AHEAD (30) calendar days after the order date. [v1.1 | 2026-10-25] |
| BR-9 | Cancellation and capacity: when an order is later cancelled by the shop, its cakes count again toward the remaining amount of its receiving date. Cancellation itself is outside this slice (no screen or endpoint cancels an order), so in this slice this rule is testable at database level only (ADR-0008): a test sets an order to Cancelled in the database and checks the date's remaining amount. [v1.3 | 2026-10-25] |
| BR-10 | Uniform rules: the same limit, lead time, slots and fees apply on every date; no closed days or special dates in this slice. [v1.1 | 2026-10-25] |
| BR-11 | Slot capacity: delivery time slots have no capacity of their own; capacity is counted per day only (BR-1). [v1.1 | 2026-10-25] |
| BR-12 | Contact data retention: name, phone number and address are kept only while needed to fulfil the order. The concrete period will be stated by the owner later (see 12.1). [v1.1 | 2026-10-25] |

## 7. Acceptance Criteria

Parameter names (LEAD_DAYS, DAILY_LIMIT, MIN_QTY, MAX_DAYS_AHEAD) stand for the shop's configured values; DAILY_LIMIT and other launch data use fake values agreed at test time. [v1.1 | 2026-10-25]

Verdict rules (v1.3): a Pass verdict needs all Must ACs to pass. Failures of ACs tied to Should requirements (AC-17 for FR-12, AC-26 for FR-18) are logged as defects but do not block a Pass verdict. Evidence level in this slice: AC-23 (stored order keeps its prices) is accepted with database-level evidence, because no screen or endpoint shows a stored order; AC-28 (BR-9) is testable at database level only. Date rules (AC-7, AC-24) are tested with a controllable server clock. [v1.3 | 2026-10-25]

| ID | Checks | Given / When / Then |
| -- | ------ | ------------------- |
| AC-1 | FR-1 | Given the app is installed, when it is opened, then a screen with only the logo appears, then the home screen. |
| AC-2 | FR-2 | Given the home screen, then shop name, greeting, Zalo button, phone button, "View products" and "Place order" are visible. |
| AC-3 | FR-2 | Given the home screen, when the Zalo or phone button is tapped, then the device opens Zalo or the phone dialer with the shop's number. |
| AC-4 | FR-3 | Given "View products" is tapped, then exactly four cakes are listed, each with picture, name, description and price. |
| AC-5 | FR-4 | Given a cake detail, when its order button is tapped, then the order flow opens with that cake at quantity 1. [v1.1 | 2026-10-25] |
| AC-6 | FR-5 | Given the cake step, when quantities 2, 0, 3, 0 are entered, then the review lists only the two cakes with quantity above 0. |
| AC-7 | FR-6, BR-2 | Given the server date in the shop time zone is D (set by a controllable clock; the device date and time zone are irrelevant), when the date picker opens, then no date earlier than D+2 can be selected, whatever the time of day (same result at 00:00:00 and 23:59:59 shop time). [v1.3 | 2026-10-25] |
| AC-8 | FR-6, BR-1 | Given a date has R cakes remaining and the order has more than R cakes, when the date picker opens, then that date cannot be selected; a date with R at least the order size can be selected. [v1.1 | 2026-10-25] |
| AC-9 | FR-10, BR-1 | Given a date was selectable and by confirmation time fewer cakes remain than the order has, when the customer tries to confirm, then the order is not confirmed and the message says the date no longer has enough capacity. [v1.1 | 2026-10-25] |
| AC-10 | FR-7, BR-11 | Given the time step, then the same fixed list of slots is offered for any chosen date, one must be chosen to proceed, and choosing a slot does not change which dates are available. [v1.1 | 2026-10-25] |
| AC-11 | FR-8, BR-3 | Given the address step, when a district is chosen, then the flat delivery fee for that district is shown and no free-delivery case exists; a district not on the list cannot be chosen. [v1.1 | 2026-10-25] |
| AC-12 | FR-13 | Given a required field is empty or the phone number is not a valid number (valid means a Vietnamese mobile number per ADR-0009; whether landlines are allowed is pending, Q-O1), when the customer proceeds, then an error appears next to the field and the flow does not advance. |
| AC-13 | FR-10, BR-4 | Given total quantity is 1, when the customer tries to confirm, then confirmation is blocked and the minimum of 2 cakes is stated; given total quantity 2 or more within the day's remaining amount, no quantity error appears. [v1.1 | 2026-10-25] |
| AC-14 | FR-9, BR-5 | Given 2 of cake A at price a, 1 of cake B at price b and district fee f, when the review is shown, then the total equals 2a + b + f. |
| AC-15 | FR-11, BR-7 | Given a valid order, when the customer confirms, then only a confirmation screen with an order code appears, with no tracking or cancel option, and the order is stored with the entered name, phone, address and note. The stored order is checked at database level (no screen or endpoint shows it in this slice). [v1.3 | 2026-10-25] |
| AC-16 | FR-11 | Given two confirmed orders, then their order codes differ. |
| AC-17 | FR-12 | Given the confirmation screen, then Zalo and phone buttons are visible and work as in AC-3. |
| AC-18 | FR-15 | Given the customer is on the review step with data entered, when going back to the cake step and forward again, then all entered data is still present. |
| AC-19 | FR-16 | Given the confirm button is tapped twice quickly or retried after a timeout, then at most one order exists for it. |
| AC-20 | FR-17 | Given the device has no connection, when the customer confirms, then no confirmation screen appears, a message says the order was not sent, and entered data is kept. |
| AC-21 | FR-14 | Given any screen or error message, then its text is in Vietnamese. This applies to text the app owns (screens, messages, labels, accessibility labels). It does not apply to text owned by the operating system (system back label, keyboard, share sheet, system permission dialogs, store listing), which follows the device language. [v1.3 | 2026-10-25] |
| AC-22 | BR-1 | Given two customers confirm at the same time when only enough capacity remains for one, then exactly one order is accepted and the other is told the date is no longer available. |
| AC-23 | BR-6 | Given a price changes after an order was confirmed, then the confirmed order still holds the price at confirmation. In this slice no screen or endpoint shows a stored order, so database-level evidence is acceptable. [v1.3 | 2026-10-25] |
| AC-24 | FR-6, BR-8 | Given the server date in the shop time zone is D (controllable clock; device clock irrelevant), when the date picker opens, then no date later than D+30 can be selected, and D+30 itself can be selected if capacity allows. [v1.3 | 2026-10-25] |
| AC-25 | FR-11 | Given an order is confirmed, then the confirmation text says the order is received and the shop will contact the customer, and does not say the order is accepted or guaranteed. [v1.1 | 2026-10-25] |
| AC-26 | FR-18 | Given the order flow, when the customer enters a note of 200 characters, then it is accepted and shown on the review; when 201 characters are entered, then the extra character is rejected with a message next to the field; when no note is entered, then the order can still be confirmed. [v1.1 | 2026-10-25] |
| AC-27 | FR-19 | Given any screen of the app including the review and confirmation, then no payment note, payment method or payment instruction is shown. [v1.1 | 2026-10-25] |
| AC-28 | BR-1, BR-9 | Given a date with a cake count at the limit, when an order for that date is cancelled (by whatever means exist), then the date's remaining amount increases by the order's cakes and the date can be selected again for orders that fit. In this slice there is no cancellation screen or endpoint, so this AC is testable at database level only (a test sets the order to Cancelled in the database). [v1.3 | 2026-10-25] |
| AC-29 | FR-2, FR-3 | Given the shop has not yet supplied sample-covered values (prices, districts, slot times, shop name, greeting, Zalo, phone), then the values used are sample values marked as sample only in the data source; no customer-visible text includes a marker word (for example "sample", "demo", "test"); and no real personal data appears. Whether a Vietnamese word such as "mau" may appear in a sample name is pending, Q-O5. [v1.3 | 2026-10-25] |
| AC-30 | FR-20 | Given the customer starts the order flow, then the privacy notice is shown before the first data entry and names the name, phone, address, optional note and the draft kept on the device. Pending owner confirmation (12.2). [v1.3 | 2026-10-25] |
| AC-31 | FR-21 | Given a date 2026-11-04 and an amount of 120000 dong, then the app shows 04/11/2026 and 120.000 with the dong unit, on the review and confirmation screens. Pending owner confirmation (12.2). [v1.3 | 2026-10-25] |

## 8. Non-functional

- Language: Vietnamese for all customer text.
- Platforms: iOS and Android phones. Look and feel is native: Liquid Glass on iOS, Material 3 Expressive on Android (design-level; minimum OS versions are Q-T3).
- Privacy: the app collects name, phone number, address and an optional note, and keeps an order draft on the device. It shall tell the customer what is collected and why before any data is entered (FR-20, pending owner confirmation), and shall not collect more than the order needs. Data is kept only while needed for fulfilment (BR-12). Store listings require a privacy disclosure (Q-T4). Apple's guideline requires that apps not force sign-in unless account features need it, which matches the no-account decision (source S-2). [v1.1 | 2026-10-25]
- Accessibility: text scales with the system font size; every control has a text label for screen readers; contrast meets WCAG 2.2 AA (4.5:1 for body text). Reasoning: public consumer app, store expectations (unverified as a store requirement).
- Performance: the order submission shall give the customer a result (confirmation or error) within 10 seconds on a normal mobile connection, otherwise show an error (FR-17). Target value proposed; owner may adjust.
- Cost: low running cost for a small shop (constraint, no number given; see Q-T5).

## 9. Impact & Dependencies

- Staff and owner features (later): will read the orders created here and supply the values for products, prices, districts, fees, daily limit and slots. Until they exist, those values must come from another source (Q-T2).
- Daily limit counting depends on cancellations returning cakes (BR-9); cancellation is a later feature. [v1.1 | 2026-10-25]
- Payment feature (later, undecided): this slice shows no payment text and must not collect payment details. [v1.1 | 2026-10-25]
- Design canvas mockups: reference only; this document is authoritative.
- External apps: Zalo and the device phone dialer.

## 10. Assumptions

- A-1: Shop timezone is Vietnam (UTC+7); all dates and times are in it.
- A-2: One order has one delivery date, time and address.
- A-3: Removed in v1.1: confirmed by the owner as BR-1 (one shared total). [v1.1 | 2026-10-25]
- A-4: Orders are requests; the shop contacts or is contacted via Zalo/phone afterwards. The confirmation says "order received, the shop will contact you" (FR-11). [v1.1 | 2026-10-25]
- A-5: Payment is settled outside the app; the app shows no payment note (FR-19). [v1.1 | 2026-10-25]
- A-6: Customers are in Vietnam; phone numbers are Vietnamese format (validation rule is Q-T6).
- A-7: Sample and test data are fake.
- A-8: The date's "order date" for BR-2 and BR-8 is the day the order is confirmed, in the shop timezone (A-1), taken from the server's date, never from the device clock or device time zone. [v1.3 | 2026-10-25]
- A-9: Launch screen time (about 1.0 to 2.0 s, from the UI design) is guidance, not a requirement; only "logo only, then home screen" (FR-1, AC-1) is required. [v1.3 | 2026-10-25]

## 11. Research & Sources

| ID | Claim | Source (URL) | Read on | Confidence |
| -- | ----- | ------------ | ------- | ---------- |
| S-1 | Bakeries typically set lead times of about 24-72 hours for standard and custom items, longer for large custom orders; a firm daily cut-off time (often evening or early afternoon) is used for planning, and weekend limits are suggested to prevent overbooking. This informed Q-1, Q-2, Q-4 (decided: 2 calendar days, no cut-off). | https://roseperl.com/?p=22183 ; https://support.breadltd.co.uk/hc/en-us/articles/4415109505810-What-are-your-order-cut-off-times ; https://findhomegrown.com/blog/order-cutoff-times-food-business | 2026-10-25 | Low to medium (vendor and shop pages, no authoritative standard) |
| S-2 | Apple App Review Guideline 5.1.1: apps should not require sign-in or personal data unless relevant to core functionality; checkout may need identity details. Taken from forum quotations, not the guideline page. | https://developer.apple.com/forums/thread/835254 | 2026-10-25 | Low (secondhand; verify on the official guideline page) |
| S-3 | Google Play Data safety requirements: not found in research. | not found | 2026-10-25 | Unverified |

## 12. Open Questions

Business questions are for the product owner; technical questions are for the architect (atlas-architect). No owner-decided question is reopened. Q-T1 to Q-T6 are closed by the ADRs (v1.3). Five new business questions (Q-O1 to Q-O5) and the items added in v1.3 are pending owner confirmation (12.2); none blocks the approved scope. [v1.3 | 2026-10-25]

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-1 | What is N, the minimum lead days between ordering and receiving? | BR-2, AC-7. | No | business | Answered [v1.1 | 2026-10-25] | N = 2 calendar days (BR-2). [v1.1 | 2026-10-25] |
| Q-2 | What is the daily cake limit, and does it count all four cakes together or per cake? What if a date has fewer cakes left than wanted? | BR-1, AC-8, AC-9. | No | business | Answered [v1.1 | 2026-10-25] | One shared daily total across all four cakes. A date is selectable only if its remaining amount covers the order. The number is a shop parameter (DAILY_LIMIT), see 12.1. [v1.1 | 2026-10-25] |
| Q-3 | What is the minimum total quantity per order, and is there a maximum? | BR-4, AC-13. | No | business | Answered [v1.1 | 2026-10-25] | Minimum 2 cakes; no maximum other than the day's remaining amount. [v1.1 | 2026-10-25] |
| Q-4 | How is lead time counted: whole days or with a daily cut-off? | BR-2 edge cases. | No | business | Answered [v1.1 | 2026-10-25] | Calendar days, no daily cut-off. [v1.1 | 2026-10-25] |
| Q-5 | Which districts are served and what is the fee for each? Is delivery ever free? | BR-3, AC-11, BR-5. | No | business | Answered [v1.1 | 2026-10-25] | Flat fee per district, no free delivery. List and fees are shop parameters, see 12.1. [v1.1 | 2026-10-25] |
| Q-6 | Which delivery time slots exist? Do they differ by weekday or have own capacity? | FR-7, AC-10. | No | business | Answered [v1.1 | 2026-10-25] | A short fixed list of slots, same every day, capacity counted per day only. Slot times are a shop parameter, see 12.1. [v1.1 | 2026-10-25] |
| Q-7 | After confirming, is the order a request the shop may still decline? | Confirmation text. | No | business | Answered [v1.1 | 2026-10-25] | Wording: "order received, the shop will contact you"; not "accepted" (FR-11, AC-25). [v1.1 | 2026-10-25] |
| Q-8 | What are the four cake prices, shop name, greeting, Zalo and phone? | FR-2, FR-3, BR-5. | No | business | Answered [v1.1 | 2026-10-25] | Sample placeholders, marked as sample only in the data source (no visible marker in the app), until the shop supplies them (AC-29); see 12.1. [v1.2 | 2026-10-25] |
| Q-9 | How does the customer pay; should the app show a payment note? | Customer expectation. | No | business | Answered [v1.1 | 2026-10-25] | Payment happens outside the app; no payment note is shown (FR-19). [v1.1 | 2026-10-25] |
| Q-10 | How far ahead may a customer order? | Date picker range. | No | business | Answered [v1.1 | 2026-10-25] | Up to 30 days ahead (BR-8). [v1.1 | 2026-10-25] |
| Q-11 | Are there special dates with different rules? | Date availability. | No | business | Answered [v1.1 | 2026-10-25] | None in this slice; uniform rules (BR-10). [v1.1 | 2026-10-25] |
| Q-12 | When staff later cancel an order, do its cakes return to the daily limit? | BR-1 over time. | No | business | Answered [v1.1 | 2026-10-25] | Yes (BR-9). [v1.1 | 2026-10-25] |
| Q-13 | Can the customer add a note? Default quantity from a cake detail? | FR-8, AC-5. | No | business | Answered [v1.1 | 2026-10-25] | One optional note, 200 characters max (FR-18); default quantity 1 (FR-4). [v1.1 | 2026-10-25] |
| Q-14 | How long is contact data kept and who may see it? | Privacy notice text. | No | business | Answered [v1.1 | 2026-10-25] | Kept while needed for fulfilment (BR-12); the retention period will be stated by the owner later, see 12.1. [v1.1 | 2026-10-25] |
| Q-T1 | How is the daily limit enforced so that two simultaneous orders cannot both exceed it (AC-22), and how is a duplicate submission detected (AC-19)? | FR-16, BR-1. | No | technical | Closed [v1.3 | 2026-10-25] | ADR-0008 (daily-limit concurrency and idempotent order creation). Price change at confirmation: ADR-0010. [v1.3 | 2026-10-25] |
| Q-T2 | Until owner configuration exists, where do products, prices, districts, fees, limits and slots come from, and how will later staff features take them over without changing this slice? | Dependency on later features. | No | technical | Closed [v1.3 | 2026-10-25] | ADR-0013 (configuration source and sample data). [v1.3 | 2026-10-25] |
| Q-T3 | Which minimum iOS and Android versions are targeted, given Liquid Glass and Material 3 Expressive availability? | Native look vs reach. | No | technical | Closed [v1.3 | 2026-10-25] | ADR-0005 (iOS 17, Android 8.0 / API 26); fallbacks ADR-0012. [v1.3 | 2026-10-25] |
| Q-T4 | What privacy disclosures do the App Store and Google Play require for collecting name, phone and address (S-3 unverified)? | Store approval. | No | technical | Closed [v1.3 | 2026-10-25] | Answered in system/deployment.md section 4 (privacy page); the store requirement itself stays unverified (S-3). [v1.3 | 2026-10-25] |
| Q-T5 | What hosting and running-cost ceiling fits a small shop? | Constraint "low cost". | No | technical | Closed [v1.3 | 2026-10-25] | ADR-0003 (hosting, free plans in the trial phase); ADR-0001, ADR-0002 for stack and database. [v1.3 | 2026-10-25] |
| Q-T6 | Phone number validation rules (Vietnamese formats, international numbers allowed?) and order code format (readable, not guessable)? | FR-8, FR-11. | No | technical | Closed [v1.3 | 2026-10-25] | ADR-0009: Vietnamese mobile numbers only; order code BT- plus 6 characters. Whether landlines should be allowed is a business question, Q-O1. [v1.3 | 2026-10-25] |

### 12.2 Added in v1.3, pending owner confirmation [v1.3 | 2026-10-25]

Nothing in this section takes effect until the owner confirms it. Current behaviour is stated for each question so that testers and developers know what exists today.

| ID | Question or added item | Current behaviour / default | Blocking | Class | Status |
| -- | ---------------------- | --------------------------- | -------- | ----- | ------ |
| Q-O1 | May customers with a landline number order? AC-12 says "valid number". | ADR-0009 accepts Vietnamese mobile numbers only; landlines are rejected. | No | business | Pending owner |
| Q-O2 | The customer cannot see the order code again once the confirmation screen is closed (no lookup, no history). Should the app keep the last order code on the device (G-3)? | Not kept; the code is shown once. | No | business | Pending owner |
| Q-O3 | The limit of 5 accepted orders per phone per 24 hours (ADR-0014): do cancelled orders count toward it? | Not decided; ADR-0014 default only. | No | business | Pending owner |
| Q-O4 | How long is customer contact data kept (BR-12)? | No period; no test expected in this slice. | No | business | Pending owner |
| Q-O5 | If sample data is visible, which wording is allowed? Sample values use the Vietnamese word "mau" in some names (for example shop and district names). | AC-29: no marker word is customer-visible; whether "mau" counts as a marker is not decided. | No | business | Pending owner |
| N-1 | FR-20 / AC-30: privacy notice before data entry covering name, phone, address, note and the draft on the device. | Today the notice appears on the review step and names name, phone, address only. | No | business | Added in v1.3, pending owner confirmation |
| N-2 | FR-21 / AC-31: dates dd/MM/yyyy and money in whole dong with dot thousands separators. | Display format not specified before. | No | business | Added in v1.3, pending owner confirmation |

### 12.1 Launch data to be provided by the shop [v1.1 | 2026-10-25]

These values are configuration, not requirements. They do not block approval of this document; they are needed before launch. Until supplied, sample values marked as sample in the data source are used; the app shows no sample marker (AC-29). The retention period remains launch data still to be supplied. [v1.2 | 2026-10-25]

| Item | Used by | Status |
| ---- | ------- | ------ |
| DAILY_LIMIT: number of cakes per day (shared across all four) | BR-1 | To be provided |
| Served districts and flat delivery fee for each (VND) | BR-3, BR-5 | To be provided |
| Delivery time slot list (start and end times, same every day) | FR-7 | To be provided |
| Prices of the four cakes (VND) | FR-3, BR-5 | Sample until provided |
| Shop name, greeting, Zalo contact, phone number | FR-2 | Sample until provided |
| Data retention period for customer contact data | BR-12 | To be stated by the owner later |

## 13. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version (Draft). |
| 1.1 | 2026-10-25 | Owner accepted proposed defaults for Q-1 to Q-14; all marked Answered. Changed FR-4, FR-6, FR-7, FR-9, FR-10, FR-11; added FR-18, FR-19. Changed BR-1 to BR-5, BR-7; added BR-8 to BR-12. Changed AC-5, AC-7 to AC-11, AC-13, AC-15; added AC-24 to AC-29. Changed G-2, non-goals, assumptions (A-3 removed, A-4, A-5 changed, A-8 added), privacy and dependencies text. Added section 12.1 launch data. Status In review. |
| 1.2 | 2026-10-25 | Owner approved v1.1 and confirmed: currency VND in whole dong (BR-5, now a confirmed fact); sample values marked as sample only in the data source, no visible marker in the app (AC-29, Q-8, 12.1). Added testability note to AC-28 (BR-9 needs cancellation to exist). Status Approved. |
| 1.3 | 2026-10-25 | Clarifications only; no owner-decided number or rule changed, Status stays Approved (v1.2). Closed Q-T1 to Q-T6 with ADR references. Server date in shop time zone for BR-2, AC-7, AC-24, A-8 (controllable clock). Database-level evidence for AC-15, AC-23, AC-28, BR-9. BR-4 technical bound of 99 per cake stated as not a business maximum. AC-29 no marker word; AC-21 scope limited to app-owned text. Launch screen time is guidance (A-9); verdict rules (Should-linked AC-17, AC-26 do not block Pass). Added FR-20, FR-21, AC-30, AC-31 and section 12.2 pending owner confirmation, with owner questions Q-O1 to Q-O5. |
