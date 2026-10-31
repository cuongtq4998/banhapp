# Admin Orders: Non-functional, Dependencies, Assumptions, Sources (sections 8 to 11)

Part of [Admin Orders](../admin-orders.md) (PRD v1.5). Holds: Non-functional, Impact & Dependencies, Assumptions A-1 to A-11, Sources S-2 to S-6. Shortened in v1.5; every line is new or changed in v1.5 [v1.5 | 2026-10-31].

## 8. Non-functional

- Simplicity (owner directive 2026-10-31): a new owner or staff member works without training. Screens use plain Vietnamese words, one main action each, no setting that is not listed in FR-20 to FR-24, and security details stay invisible (BR-4, BR-5, BR-7). [v1.5 | 2026-10-31]
- Language: Vietnamese for all text; dates dd/MM/yyyy, money in whole dong with dot separators (Place Order FR-21). [v1.5 | 2026-10-31]
- Platforms: iOS and Android at the same time (D-2), native look. [v1.5 | 2026-10-31]
- Security: sign-in is the only way to customer data; every action is authorised on the server; codes and credentials are not stored readable; the sign-in screen never reveals which addresses exist. Accepted risk (Q-18): the owner mailbox alone opens the owner account; the owner is warned by e-mail on a new phone (FR-7). The review account is on only around store review (BR-14). [v1.5 | 2026-10-31]
- Privacy: staff see name, phone and address, which is personal data: active accounts only, finished orders for 90 days (BR-9), none in notifications, logs or analytics (BR-7). The store declaration of the admin app states this. Staff e-mail addresses are used only for sign-in and the notice of FR-7. [v1.5 | 2026-10-31]
- Performance (proposed). Normal connection means 4G, at least 5 Mbit/s, round trip at most 300 ms. Server: list page of 50 within 1 second and a status change within 2 seconds for 95 percent of requests. Phone: first rows within 3 seconds, status result within 5 seconds, otherwise an error with retry. The code mail is handed to the mail service within 60 seconds. [v1.5 | 2026-10-31]
- Accessibility: text scales with system font size; every control has a text label; contrast meets WCAG 2.2 AA; status and "overdue" are never shown by colour alone (each has its word). [v1.5 | 2026-10-31]
- Cost: no SMS (Q-3). E-mail is cheap at this volume (S-5). Paid hosting is not approved (Q-21): free tier first, goals G-1 and G-4 are best effort there; ask again before real customers rely on the app. [v1.5 | 2026-10-31]

## 9. Impact & Dependencies

- Place Order: reads the same orders; settings change its catalog, availability, lead days and minimum; the catalog may hold up to 12 cakes with owner images; cancelled orders stop counting toward the phone limit except "fake or spam" (FR-27). Place Order v1.6 already records this and cites only Q-12 and Q-17, so it needs no change from v1.5. [v1.5 | 2026-10-31]
- Retention of stored customer data stays open (PO Q-O4); the 90 days are a display rule only. [v1.5 | 2026-10-31]
- Backend: endpoints for sign-in, orders, settings, "sign out other phones"; cancel reason, removed-cake state and the change record need stored data. docs/system/auth.md v2.0, ADR-0022 and ADR-0027 stand; recovery parts of auth.md and the device list are deferred (owner accepted Q-25 and Q-26 on 2026-10-31; TQ-10 to TQ-13 in 07). [v1.6 | 2026-10-31]
- Design: docs/design/admin-orders/ (20 screens) must follow the v1.5 id mapping (08). Screens for the device list, recovery, backup e-mail, Unfinished view, chip and banner are not needed (Q-25 to Q-27 accepted by the owner on 2026-10-31). [v1.6 | 2026-10-31]
- External: e-mail delivery service, Apple and Google push, Zalo and the phone dialer. [v1.5 | 2026-10-31]

## 10. Assumptions

- A-1: Shop timezone Vietnam (UTC+7); "today" is the server date in that zone.
- A-2: One shop; the first owner account is created by the operator outside the app; no self-registration.
- A-3: Staff are few (up to 30); any staff member may act on any order; no assignment.
- A-4: Each person uses one to three personal phones with mobile data and e-mail.
- A-5: At most about 100 orders a day.
- A-6: Customers are contacted by phone or Zalo outside the app.
- A-7: If the owner cannot open the owner mailbox, the operator recovers the account outside the app (this is the only recovery in v1.6, P-1 accepted). [v1.6 | 2026-10-31]
- A-8: The sender and wording of the code mail are chosen by the architect.
- A-9: Sample and test data are fake.
- A-10: Values marked "proposed" are author defaults; a changed value is written into this document first (new version and change log).
- A-11: Store reviewers can use the fixed-code review account for the whole review (S-3, unverified); the operator switches it off afterwards.

## 11. Research & Sources

| ID | Claim | Source (URL) | Read on | Confidence |
| -- | ----- | ------------ | ------- | ---------- |
| S-2 | Apple unlisted app distribution: reachable by direct link, not in search or charts. | https://developer.apple.com/support/unlisted-app-distribution | 2026-10-31 | Medium |
| S-3 | App review expects a demo account for any app with sign-in. | not read from the official guideline page | 2026-10-31 | Unverified |
| S-4 | Mobile OS share in Vietnam: Android about 60 percent, iOS about 40 percent. | https://gs.statcounter.com/os-market-share/mobile/viet-nam | 2026-10-31 | Medium |
| S-5 | Transactional e-mail is cheap: free tiers of about 100 to 500 mails a day exist; expected volume is far below. | https://www.ilounge.com/articles/resend-alternatives-6-transactional-email-apis-compared-on-price | 2026-10-31 | Low to medium |
| S-6 | Refresh-token rotation with revocation on replay is current OAuth practice (RFC 9700). | https://www.rfc-editor.org/rfc/rfc9700 | 2026-10-31 | Medium |
