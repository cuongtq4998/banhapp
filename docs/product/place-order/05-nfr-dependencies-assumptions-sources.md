# Place Order: Non-functional, Dependencies, Assumptions, Sources (sections 8 to 11)

Part of [Place Order](../place-order.md) (PRD v1.6). Holds: Non-functional, Impact & Dependencies, Assumptions A-1 to A-9, Research & Sources S-1 to S-3. [v1.6 | 2026-10-31]

## 8. Non-functional

- Language: Vietnamese for all customer text.
- Platforms: iOS and Android phones. Look and feel is native: Liquid Glass on iOS, Material 3 Expressive on Android (design-level; minimum OS versions are Q-T3).
- Privacy: the app collects name, phone number, address and an optional note, and keeps an order draft on the device. It shall tell the customer what is collected and why before any data is entered (FR-20, confirmed by the owner 2026-10-29) [v1.5 | 2026-10-29], and shall not collect more than the order needs. Data is kept only while needed for fulfilment (BR-12). Store listings require a privacy disclosure (Q-T4). Apple's guideline requires that apps not force sign-in unless account features need it, which matches the no-account decision (source S-2). [v1.1 | 2026-10-25]
- Accessibility: text scales with the system font size; every control has a text label for screen readers; contrast meets WCAG 2.2 AA (4.5:1 for body text). Reasoning: public consumer app, store expectations (unverified as a store requirement).
- Performance: the order submission shall give the customer a result (confirmation or error) within 10 seconds on a normal mobile connection, otherwise show an error (FR-17). Target value proposed; owner may adjust.
- Cost: low running cost for a small shop (constraint, no number given; see Q-T5).

## 9. Impact & Dependencies

- Staff and owner features (Admin Orders, PRD v1.3; was "later"): [v1.6 | 2026-10-31] will read the orders created here and supply the values for products, prices, districts, fees, daily limit and slots. Until they exist, those values must come from another source (Q-T2).
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
