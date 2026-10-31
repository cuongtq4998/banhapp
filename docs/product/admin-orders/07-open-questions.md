# Admin Orders: Open Questions and Change Log (sections 12 and 13)

Part of [Admin Orders](../admin-orders.md) (PRD v1.6). Holds: Q-1 to Q-28 (business, all decided), TQ-1 to TQ-13 (technical), design answers, the change log. Condensed in v1.5; every line is new or changed in v1.5 [v1.5 | 2026-10-31].

## 12. Open Questions

### 12.1 Business questions open for the owner

None. Q-25 to Q-28 (simplification proposals P-1 to P-4) were answered by the owner on 2026-10-31 and are listed in 12.2. [v1.6 | 2026-10-31]

### 12.2 Business questions already decided

| ID | Topic | Decision |
| -- | ----- | -------- |
| Q-1, Q-2 | App shape | Separate app, iOS and Android together (D-1, D-2). |
| Q-3 | Sign-in channel | E-mail plus code, no SMS (BR-4). |
| Q-4, Q-15 | Sessions | 7 days, renewed on each use (BR-5); device list replaced by "Sign out all other phones" (Q-26). [v1.6 | 2026-10-31] |
| Q-5 | Accounts | One owner, up to 30 staff (BR-6). |
| Q-6, Q-17 | Cakes | Add, hide, remove; at most 12 (BR-12). |
| Q-7 | Ordering rules | Daily limit, lead days, minimum cakes (FR-22). |
| Q-8 | Complete | Any time after Confirmed (FR-17). |
| Q-9 | Cancel reason | Required, fixed list (BR-8); four reasons (Q-28). [v1.6 | 2026-10-31] |
| Q-10 | Editing orders | None (non-goal). |
| Q-11 | Notifications | Everyone signed in gets each order; no reminders (FR-25). |
| Q-12 | Phone limit | Cancelled orders not counted except spam (FR-27). |
| Q-13 | Order window | 90 days for finished orders (BR-9). |
| Q-14, Q-16 | Recovery | Backup e-mail and two-code recovery dropped from this version; operator helps (Q-25). [v1.6 | 2026-10-31] |
| Q-18 | Owner sign-in | One code (FR-1). |
| Q-19 | Store review | Fixed-code demo account (BR-14). |
| Q-20 | Lockout | No time lock; 5th wrong entry voids the code (BR-4). |
| Q-21 | Paid hosting | Not approved; free tier first. |
| Q-22 | Unfinished orders | Badge and red marks in the one list; separate view, chip, banner dropped (Q-27). [v1.6 | 2026-10-31] |
| Q-23 | Daily reminder push | Withdrawn, default none (D-8). |
| Q-24 | New-device notice | Yes, to owner e-mail (FR-7); backup address part dropped with Q-25. [v1.6 | 2026-10-31] |
| Q-25 | Recovery (P-1) | (a) Yes: drop backup e-mail and two-code recovery; a lost phone is solved by one code on the new phone plus "Sign out all other phones"; a lost owner mailbox is solved by the operator outside the app. Accepted 2026-10-31. [v1.6 | 2026-10-31] |
| Q-26 | Phone list (P-2) | (a) Yes: one button "Sign out all other phones" for everyone instead of a device list. Accepted 2026-10-31. [v1.6 | 2026-10-31] |
| Q-27 | Unfinished view (P-3) | (a) Yes: badge plus red overdue marks in the one list; no separate view, chip or banner. Accepted 2026-10-31. [v1.6 | 2026-10-31] |
| Q-28 | Cancel reasons (P-4) | (a) Yes: four reasons (customer asked, cannot deliver, cannot reach customer, fake or spam). Accepted 2026-10-31. [v1.6 | 2026-10-31] |

### 12.3 Technical questions (for the architect)

| ID | Question | Status |
| -- | -------- | ------ |
| TQ-1 | E-mail delivery service and code delivery in test. | Open |
| TQ-2 | Delivery of the admin app to a small audience on both platforms (S-2). | Open |
| TQ-3 | Push service, guarantees, token handling at sign-out, switch-off and sign-out of other phones. | Open |
| TQ-4 | Sessions: ADR-0022 accepted, including the 20-second grace (BR-5). | Closed |
| TQ-5 | Stale-view conflicts for status changes; indexing for list, filter, search. | Open |
| TQ-6 | Image upload for new cakes: formats, size, storage, resizing. | Open |
| TQ-7 | 90-day rule for finished orders only, open orders exempt (BR-9, simpler than v1.4). | Open |
| TQ-8 | Place-order limit ignoring cancelled orders except spam; storing the reason. | Open |
| TQ-9 | Identify a phone only to know "not used before" (FR-7) and to sign out other phones (FR-4); no device names needed. | Open |
| TQ-10 | Recovery codes and backup e-mail: not needed (Q-25 accepted). | Deferred |
| TQ-11 | Align ADR-0022 counters with BR-4 (no time lock, 5th wrong entry voids the code, limit per client address). | Open |
| TQ-12 | Unfinished count: how the server serves the badge cheaply (New or Confirmed, date at or before shop day, any age); open orders exempt from the 90-day rule. | Open |
| TQ-13 | New-device notice without blocking sign-in. | Open |

### 12.4 Design answers

Q-D1 (recovery way-in always shown) is void (Q-25 accepted). Q-D2 accepted (Complete asks one confirmation, FR-17). Q-D3 stays with the design owner. Q-D4 (staff account button) stays, with sign-out only plus "Sign out all other phones" (FR-4). [v1.5 | 2026-10-31]

## 13. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 to 1.4 | 2026-10-31 | First version, owner answers Q-1 to Q-14, approval of v1.2, review findings, Unfinished view and new-device notice. Full text of those versions is in git history. |
| 1.5 | 2026-10-31 | Simplification review after the owner directive that all apps be easy for every kind of user. New "How a day works" (01 section 0). Rewritten: 52 FRs to 27, 28 BRs to 14, 103 ACs to 48; old ids in 08 section 15. Deferred list in 08 section 14. Proposals changing owner decisions: P-1 recovery (Q-25), P-2 device list (Q-26), P-3 Unfinished view, chip, banner (Q-27), P-4 four cancel reasons (Q-28). Invisible-by-design: code and session limits, record, 90-day rule, review account. Q-23 withdrawn. New questions Q-25 to Q-28; TQ-10 to TQ-13 revised. |
| 1.6 | 2026-10-31 | Owner accepted P-1 to P-4 (Q-25 to Q-28, all option a) on 2026-10-31. Status Approved. Q-25 to Q-28 closed as decided; Deferred list confirmed; PROPOSAL marks removed. No requirement text changed otherwise; ids and counts unchanged (27 FRs, 14 BRs, 48 ACs). |
