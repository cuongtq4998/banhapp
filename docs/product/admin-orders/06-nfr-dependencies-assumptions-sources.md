# Admin Orders: Non-functional, Dependencies, Assumptions, Sources (sections 8 to 11)

Part of [Admin Orders](../admin-orders.md) (PRD v1.0). Holds: Non-functional, Impact & Dependencies, Assumptions A-1 to A-10, Research & Sources S-1 to S-4.

## 8. Non-functional

- Language: Vietnamese for all text. Dates as dd/MM/yyyy and money in whole dong with dot thousands separators, as in Place Order FR-21.
- Platforms: see D-1 and D-2 in [01-overview.md](01-overview.md); native look as in the customer app.
- Security: sign-in is the only way to see customer data. Responses to the sign-in screen do not reveal whether a number is registered (FR-1). Code requests cost money, so they are limited (BR-5). Codes and session credentials are not stored in readable form. Every settings and status action is authorised on the server (FR-5, FR-21).
- Privacy: staff see customer name, phone and address, which is personal data. Access is limited to active accounts (BR-15), the data is not placed in notifications, logs or analytics, and the privacy notice and store declaration of the admin app state this use (see PO NFR on privacy).
- Performance (proposed): the order list shows its first rows within 3 seconds on a normal mobile connection, and a status change shows its result within 5 seconds, otherwise an error with retry shows.
- Accessibility: text scales with the system font size; every control has a text label; contrast meets WCAG 2.2 AA (4.5:1 body text); status is never shown by colour alone (each status has its word).
- Cost: the only new running cost expected is text messages for codes (Q-3) and the store records of the admin app (Q-1). Push services are expected to be free at this volume (unverified, left to the architect, TQ-3).

## 9. Impact & Dependencies

- Place Order: reads the same orders. The customer app and its API are not changed, except that settings now change what they return (catalog, availability) and that cancellation now exists, which makes PO BR-9 testable end to end.
- Place Order Q-O3 (do cancelled orders count toward the 5-orders-per-phone limit) becomes live because staff can now cancel; see Q-12.
- Place Order Q-O4 (retention period for contact data) applies to what staff see.
- Backend: new endpoints for sign-in, orders and settings (designed by the architect); the database already guards status changes and releases capacity on cancellation (docs/system/order-lifecycle.md).
- docs/system/auth.md holds a placeholder for this sign-in and says that SMS costs money and needs owner approval; Q-3 is that approval.
- Design: reference screens A1 to A4 (sign-in, order list, detail, settings) exist for iOS and Android; they are reference only and this document is authoritative. They show two tabs (orders, settings), staff seeing only orders, a 30-second resend wait and a "remembered N days" note.
- External: SMS provider, Apple and Google push services, Zalo and the phone dialer.

## 10. Assumptions

- A-1: Shop timezone is Vietnam (UTC+7); "today" and "tomorrow" use the server date in that zone (Place Order A-1, A-8).
- A-2: There is one shop. The first owner account is created by the system operator at launch, outside the app; the app has no self-registration.
- A-3: Staff are few (about 1 to 10) and all work for the same shop; any staff member may act on any order. No per-staff assignment.
- A-4: Each person signs in on one to three personal devices; these devices have mobile data.
- A-5: The shop handles at most about 100 orders a day; list size and push volume are small.
- A-6: Orders are handled by phone or Zalo outside the app; no in-app messaging with customers.
- A-7: A lost owner phone is recovered by the operator, outside the app (no recovery flow in this slice).
- A-8: The code is sent as a text message to the phone number; the sender and wording are chosen by the architect and cost owner approval (Q-3).
- A-9: Sample and test data are fake.
- A-10: Values marked "proposed" in BR-5, BR-6, BR-8, BR-9, BR-13 and the performance figures are defaults chosen by the author; the owner may change them.

## 11. Research & Sources

| ID | Claim | Source (URL) | Read on | Confidence |
| -- | ----- | ------------ | ------- | ---------- |
| S-1 | Business text messages in Vietnam, including one-time codes, need a registered sender name; approval takes weeks to months; the brand name must appear in the message; cost is roughly 200 to 500 VND per message locally, higher through international providers. Figures come from vendors, not carriers. | https://www.telerivet.com/blog/vietnam-sms-compliance-mic-zalo ; https://docs.linkmobility.com/regulatory-guidelines/sender-id/vietnam ; https://docs.botble.com/sms-gateways/drivers/esmsvn.html | 2026-10-31 | Low to medium (vendor pages) |
| S-2 | Apple unlisted app distribution: the app is reachable only by a direct link or through managed distribution, not shown in search, categories or charts; Apple recommends an authentication flow in case the link leaks. | https://developer.apple.com/support/unlisted-app-distribution | 2026-10-31 | Medium (search summary of Apple page) |
| S-3 | App review expects reviewers to be able to use every feature, which means a demo account for any app with sign-in. | not read from the official guideline page in this research | 2026-10-31 | Unverified |
| S-4 | Mobile operating system share in Vietnam: Android about 60 percent, iOS about 40 percent (June and July 2026 pages; other pages mixing desktop data disagree). | https://gs.statcounter.com/os-market-share/mobile/viet-nam | 2026-10-31 | Medium |
