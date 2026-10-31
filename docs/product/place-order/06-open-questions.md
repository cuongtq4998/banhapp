# Place Order: Open Questions and Launch Data (section 12)

Part of [Place Order](../place-order.md) (PRD v1.4.1). Holds: Q-1 to Q-15, Q-T1 to Q-T6, section 12.2 (Q-O1 to Q-O5, N-1, N-2), section 12.1 launch data. [v1.4.1 | 2026-10-27]

## 12. Open Questions

Business questions are for the product owner; technical questions are for the architect (atlas-architect). No owner-decided question is reopened. Q-T1 to Q-T6 are closed by the ADRs (v1.3). Five new business questions (Q-O1 to Q-O5) are pending owner confirmation (12.2); none blocks the approved scope. N-1 and N-2 (FR-20, FR-21) were answered by the owner on 2026-10-29. [v1.5 | 2026-10-29]

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
| Q-15 | When fewer than four cakes are active, what does the customer see? (QA finding DOC-8, Q-S6 area) | FR-3, BR-13, AC-4, AC-32 to AC-34. | No | business | Answered [v1.4 | 2026-10-26] | Owner decision 2026-10-26: the app shows the active cakes (1 to 4 are all normal); an Error state only when zero cakes are active. The shop can hide one cake temporarily and customers can still order the rest. [v1.4 | 2026-10-26] |
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
| Q-O5 | If sample data is visible, which wording is allowed? Sample values use the Vietnamese word "mau" in some names (for example shop and district names). | AC-29 (v1.4): no marker word is customer-visible, and "mẫu" / "mau" in the sense of "sample" counts as a marker word, so displayed seed values must not contain it; technical documents may use it. Owner may overrule. | No | business | Pending owner (default applied in v1.4) |
| N-1 | FR-20 / AC-30: privacy notice before data entry covering name, phone, address, note and the draft on the device. | Today the notice appears on the review step and names name, phone, address only. | No | business | Answered [v1.5 | 2026-10-29]: owner confirmed FR-20 as written, with the full privacy notice shown on S-7 (recipient screen) and a one-sentence reminder with link on S-8 (2026-10-29) |
| N-2 | FR-21 / AC-31: dates dd/MM/yyyy and money in whole dong with dot thousands separators. | Display format not specified before. | No | business | Answered [v1.5 | 2026-10-29]: owner confirmed FR-21 as written (2026-10-29) |

### 12.1 Launch data to be provided by the shop [v1.1 | 2026-10-25]

These values are configuration, not requirements. They do not block approval of this document; they are needed before launch. Until supplied, sample values marked as sample in the data source are used; the app shows no sample marker (AC-29). The retention period remains launch data still to be supplied. [v1.2 | 2026-10-25]

| Item | Used by | Status |
| ---- | ------- | ------ |
| DAILY_LIMIT: number of cakes per day (shared across all products) | BR-1 | To be provided [v1.4 | 2026-10-26] |
| Served districts and flat delivery fee for each (VND) | BR-3, BR-5 | To be provided |
| Delivery time slot list (start and end times, same every day) | FR-7 | To be provided |
| Four launch cakes, all active at launch, and their prices (VND) | FR-3, BR-5, BR-13 | Sample until provided [v1.4 | 2026-10-26] |
| Shop name, greeting, Zalo contact, phone number | FR-2 | Sample until provided |
| Data retention period for customer contact data | BR-12 | To be stated by the owner later |
