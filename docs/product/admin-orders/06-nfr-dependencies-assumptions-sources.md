# Admin Orders: Non-functional, Dependencies, Assumptions, Sources (sections 8 to 11)

Part of [Admin Orders](../admin-orders.md) (PRD v1.1). Holds: Non-functional, Impact & Dependencies, Assumptions A-1 to A-10, Research & Sources S-1 to S-6. Changed or new lines end with [v1.1 | 2026-10-31].

## 8. Non-functional

- Language: Vietnamese for all text. Dates as dd/MM/yyyy and money in whole dong with dot thousands separators, as in Place Order FR-21.
- Platforms: iOS and Android, built at the same time (D-2); native look as in the customer app. [v1.1 | 2026-10-31]
- Security: sign-in is the only way to see customer data. Responses to the sign-in screen do not reveal whether an address is registered (FR-1). Code requests are limited to stop abuse (BR-5). Codes and session credentials are not stored in readable form. A reused renewal credential signs the device out (FR-36). Every settings and status action is authorised on the server (FR-5, FR-21). Owner recovery needs two mailboxes (BR-17). [v1.1 | 2026-10-31]
- Privacy: staff see customer name, phone and address, which is personal data. Access is limited to active accounts (BR-15), to orders of the last 90 days (BR-20), the data is not placed in notifications, logs or analytics, and the privacy notice and store declaration of the admin app state this use (see PO NFR on privacy). Staff and owner e-mail addresses are personal data too and are used only for sign-in and the notices of FR-43. [v1.1 | 2026-10-31]
- Performance (proposed): the order list shows its first rows within 3 seconds on a normal mobile connection, and a status change shows its result within 5 seconds, otherwise an error with retry shows. A sign-in code e-mail arrives within 60 seconds in normal conditions (proposed). [v1.1 | 2026-10-31]
- Accessibility: text scales with the system font size; every control has a text label; contrast meets WCAG 2.2 AA (4.5:1 body text); status is never shown by colour alone (each status has its word).
- Cost: no text-message cost (decided, Q-3). The new running costs are e-mail delivery, which is low at this volume (S-5), and the store records of the admin app (D-1). Push services are expected to be free at this volume (unverified, left to the architect, TQ-3). No money decision is asked of the owner. [v1.1 | 2026-10-31]

## 9. Impact & Dependencies

- Place Order: reads the same orders. Its API changes in four ways: settings change what it returns (catalog, availability, lead days, minimum cakes); cancellation now exists, which makes PO BR-9 testable end to end; the catalog may hold more than four cakes with owner-supplied images (the customer app was designed for at most four cakes with fixed photos), so its catalog screen and its rules text must follow BR-18 and BR-21; and the per-phone limit changes as below. [v1.1 | 2026-10-31]
- Cross-feature impact, decided Q-12: Place Order Q-O3 is answered. A cancelled order does not count toward the limit of 5 orders per phone per 24 hours, except one cancelled with the reason "fake or spam order". The place-order backend rule must change (FR-44, BR-16); Place Order BR and ACs that state the limit need an update by that feature's owner. [v1.1 | 2026-10-31]
- Place Order Q-O4 (retention period for contact data) applies to stored data; staff see only the last 90 days (BR-20). [v1.1 | 2026-10-31]
- Backend: new endpoints for sign-in, devices, orders and settings (designed by the architect); the database already guards status changes and releases capacity on cancellation (docs/system/order-lifecycle.md); a cancel reason and removed-cake state need new stored data. [v1.1 | 2026-10-31]
- docs/system/auth.md holds a placeholder for this sign-in and says that SMS costs money; since SMS is dropped (Q-3) the architect updates it to e-mail codes. [v1.1 | 2026-10-31]
- Design: reference screens A1 to A4 exist for iOS and Android; they are reference only and this document is authoritative. They show a phone-number sign-in, a 30-second resend wait and a "remembered N days" note, which must change to e-mail and 7 days; they show no device list, backup e-mail, cake add or remove, cancel reason or ordering rules. [v1.1 | 2026-10-31]
- External: an e-mail delivery service (low cost, S-5), Apple and Google push services, Zalo and the phone dialer. [v1.1 | 2026-10-31]

## 10. Assumptions

- A-1: Shop timezone is Vietnam (UTC+7); "today" and "tomorrow" use the server date in that zone (Place Order A-1, A-8).
- A-2: There is one shop. The first owner account is created by the system operator at launch, outside the app; the app has no self-registration.
- A-3: Staff are few (up to 30) and all work for the same shop; any staff member may act on any order. No per-staff assignment. [v1.1 | 2026-10-31]
- A-4: Each person signs in on one to three personal devices; these devices have mobile data and can receive e-mail. [v1.1 | 2026-10-31]
- A-5: The shop handles at most about 100 orders a day; list size and push volume are small.
- A-6: Orders are handled by phone or Zalo outside the app; no in-app messaging with customers.
- A-7: If the owner has no backup e-mail, or loses access to both mailboxes, the operator recovers the account outside the app. [v1.1 | 2026-10-31]
- A-8: The code is sent by e-mail; the sender and wording are chosen by the architect. [v1.1 | 2026-10-31]
- A-9: Sample and test data are fake.
- A-10: Values marked "proposed" in BR-5, BR-6, BR-8, BR-9, BR-13, BR-18 and the performance figures are defaults chosen by the author; the owner may change them.

## 11. Research & Sources

| ID | Claim | Source (URL) | Read on | Confidence |
| -- | ----- | ------------ | ------- | ---------- |
| S-1 | Removed in v1.1: text-message codes are no longer used (Q-3). The finding that Vietnamese business SMS needs sender registration and costs about 200 to 500 VND per message is kept only as the reason SMS was a money question. | https://www.telerivet.com/blog/vietnam-sms-compliance-mic-zalo | 2026-10-31 | Low to medium (vendor page) |
| S-2 | Apple unlisted app distribution: the app is reachable only by a direct link or through managed distribution, not shown in search, categories or charts; Apple recommends an authentication flow in case the link leaks. | https://developer.apple.com/support/unlisted-app-distribution | 2026-10-31 | Medium (search summary of Apple page) |
| S-3 | App review expects reviewers to be able to use every feature, which means a demo account for any app with sign-in. | not read from the official guideline page in this research | 2026-10-31 | Unverified |
| S-4 | Mobile operating system share in Vietnam: Android about 60 percent, iOS about 40 percent (June and July 2026 pages; other pages mixing desktop data disagree). | https://gs.statcounter.com/os-market-share/mobile/viet-nam | 2026-10-31 | Medium |
| S-5 | Transactional e-mail is cheap: free tiers of about 100 to 500 e-mails a day or 3 000 a month exist at several providers, and pay-per-use is about 0.10 USD per 1 000 e-mails. Expected volume here (tens of people, one code a week each) is far below a free tier. Figures come from comparison sites and vary; verify on the provider's page before choosing. | https://www.ilounge.com/articles/resend-alternatives-6-transactional-email-apis-compared-on-price ; https://dupple.com/learn/best-transactional-email-services | 2026-10-31 | Low to medium (third-party comparisons) |
| S-6 | Refresh-token rotation (a refresh credential works once) and revoking the whole sign-in when an old one is replayed are current OAuth security practice (RFC 9700, section 4.14). The exact normative wording was not read in this research. | https://www.rfc-editor.org/rfc/rfc9700 ; https://django-oauth-toolkit.readthedocs.io/en/latest/security.html | 2026-10-31 | Medium (secondary summaries) |
