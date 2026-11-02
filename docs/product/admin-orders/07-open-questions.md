# Admin Orders: Open Questions and Change Log (sections 12 and 13)

Part of [Admin Orders](../admin-orders.md) (PRD v1.10). Holds: Q-1 to Q-38 (business; Q-29 to Q-34 answered 2026-11-02, Q-35 and Q-36 assumed, Q-37 and Q-38 answered 2026-11-02) [v1.11 | 2026-11-02], TQ-1 to TQ-13 (technical; open: TQ-1, TQ-2, TQ-3) [v1.8 | 2026-11-01], design answers, the change log. Condensed in v1.5; every line is new or changed in v1.5 [v1.5 | 2026-10-31].

## 12. Open Questions

### 12.1 Business questions open for the owner

| ID | Question | Affects | Blocking | Type | Status | Recommendation |
| -- | -------- | ------- | -------- | ---- | ------ | -------------- |
| Q-29 | May the shop set a delivery fee of 0 (free delivery)? | BR-11, AC-40, PO BR-3, PO AC-11 | No | business | Answered 2026-11-02 | The owner answered differently: the fee is not known at order time, it becomes known when delivery starts (09 section 16). Fee 0 is allowed for the real fee (Q-33, applied in v1.10). [v1.10 | 2026-11-02] |
| Q-30 | What does the customer see about the fee when ordering: no fee ("told later"), or the district fee as an estimate? | C-1, C-6, PO FR-9 | Yes | business | Answered 2026-11-02 | Owner: the customer sees the district fee as an estimate with the text that the final fee is told at delivery. (FR-23, BR-15, PO FR-9) [v1.10 | 2026-11-02] |
| Q-31 | Who pays the real fee, and when: the customer to the courier at delivery, or the shop adds it to the total? Is the total on the order only for cakes? | C-1, C-6 | Yes | business | Answered 2026-11-02 | Owner: the customer pays the cakes plus the real fee when the cakes are handed over; the order stores the cake amount and the real fee once it is entered. (BR-15, PO BR-5) [v1.10 | 2026-11-02] |
| Q-32 | Which exact step is "being made" (Processing, or Delivery date scheduled)? Who may cancel before it: customer, shop, or both? | C-4, C-5, OD-3 | Yes | business | Answered 2026-11-02 | Owner: cancel is not possible from "Delivery date scheduled" onward; from receiving the order through the end of Processing it is allowed, by staff and owner; the customer does not cancel in the app (existing rule kept). (BR-2, FR-18) [v1.10 | 2026-11-02] |
| Q-33 | Who enters the real fee, at which step, and may it be 0? | C-2, C-3 | Yes | business | Answered 2026-11-02 | Owner: staff or owner enter the real delivery fee when pressing "Start delivery"; entering it is required; 0 is allowed (free delivery). (FR-29, BR-11) [v1.10 | 2026-11-02] |
| Q-34 | Who sets the expected delivery date and when, and may it be moved more than once? Is Finished allowed only after Delivery started? | C-4, C-7 | Yes | business | Answered 2026-11-02 | Owner: staff or owner schedule the expected delivery date when Processing ends; it may be changed any number of times, each change recorded (who, when, old and new date); Finished only after Delivery started. (FR-28, FR-17, BR-15) [v1.10 | 2026-11-02] |
| Q-35 | Is the customer told when the expected date is set or moves (message, call by staff, nothing)? | C-7 | No | business | Assumed, to confirm | Not answered by the owner. Assumption: no automatic message; staff call (Call and Zalo exist). In BR-15. [v1.10 | 2026-11-02] |
| Q-36 | Existing orders: what are the old statuses mapped to? Does the customer date and daily limit stay as is? Do new open steps count as unfinished? | C-7, C-8 | No | business | Assumed, to confirm | Not answered by the owner. Assumptions: New to Received, Confirmed to Processing, Completed to Finished; the customer-chosen date stays as the requested date and keeps counting toward the daily limit; the new open steps count as unfinished. In BR-2, BR-9, BR-15. [v1.10 | 2026-11-02] |
| Q-37 | Which date drives the red "due" marks, the badge and the list order once an expected date is set: the expected date, or the requested date? | BR-9, FR-9, FR-13, AC-52 | No | business | Answered 2026-11-02 | Owner (explicit answer): use the expected delivery date when set, otherwise the requested date, for the red "due" marks, the badge and the list order. Decision in BR-9. [v1.11 | 2026-11-02] |
| Q-38 | When the expected date moves to another day, should the cakes count toward that day's limit instead of the requested date? | BR-15, PO BR-9 | No | business | Answered 2026-11-02 | Owner (explicit answer): no, moving the expected date does not move cakes into the new day's daily limit; the limit stays on the customer-chosen date. Decision in BR-15. [v1.11 | 2026-11-02] |

Q-25 to Q-28 (simplification proposals P-1 to P-4) were answered by the owner on 2026-10-31 and are listed in 12.2. [v1.7 | 2026-11-01]

### 12.2 Business questions already decided

| ID | Topic | Decision |
| -- | ----- | -------- |
| Q-1, Q-2 | App shape | Separate app, iOS and Android together (D-1, D-2). |
| Q-3 | Sign-in channel | E-mail plus code, no SMS (BR-4). |
| Q-4, Q-15 | Sessions | 7 days, renewed on each use (BR-5); device list replaced by "Sign out all other phones" (Q-26). [v1.6 | 2026-10-31] |
| Q-5 | Accounts | One owner, up to 30 staff (BR-6). |
| Q-6, Q-17 | Cakes | Add, hide, remove; at most 12 (BR-12). |
| Q-7 | Ordering rules | Daily limit, lead days, minimum cakes (FR-22). |
| Q-8 | Complete | Any time after Confirmed (FR-17). Superseded 2026-11-02 by Q-34: Finished only after Delivery started. [v1.10 | 2026-11-02] |
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
| TQ-1 | E-mail delivery service and code delivery in test. | Open. Test delivery is answered (recording sender); real e-mail delivery is not: sender domain and provider are unapproved (money, DP-Q4; ADR-0023 Proposed). [v1.8 | 2026-11-01] |
| TQ-2 | Delivery of the admin app to a small audience on both platforms (S-2). | Open. Decided in ADR-0026 but not verified against the stores; store fees are unapproved. [v1.8 | 2026-11-01] |
| TQ-3 | Push service, guarantees, token handling at sign-out, switch-off and sign-out of other phones. | Open. Built behind a push sender and token handling is answered; not verified on live APNs and FCM (no accounts, no device test). [v1.8 | 2026-11-01] |
| TQ-4 | Sessions: ADR-0022 accepted, including the 20-second grace (BR-5). | Closed |
| TQ-5 | Stale-view conflicts for status changes; indexing for list, filter, search. | Closed: built (architecture 16 section 32.4). [v1.8 | 2026-11-01] |
| TQ-6 | Image upload for new cakes: formats, size, storage, resizing. | Closed: built (architecture 16 section 32.4). [v1.8 | 2026-11-01] |
| TQ-7 | 90-day rule for finished orders only, open orders exempt (BR-9, simpler than v1.4). | Closed: built (architecture 16 section 32.4). [v1.8 | 2026-11-01] |
| TQ-8 | Place-order limit ignoring cancelled orders except spam; storing the reason. | Closed: built (architecture 16 section 32.4). [v1.8 | 2026-11-01] |
| TQ-9 | Identify a phone only to know "not used before" (FR-7) and to sign out other phones (FR-4); no device names needed. Answered by ADR-0022 and ADR-0031 (architecture 05). | Closed [v1.7 | 2026-11-01] |
| TQ-10 | Recovery codes and backup e-mail: not needed (Q-25 accepted). | Deferred |
| TQ-11 | Align ADR-0022 counters with BR-4 (no time lock, 5th wrong entry voids the code, limit per client address). | Closed: built (architecture 16 section 32.4). [v1.8 | 2026-11-01] |
| TQ-12 | Unfinished count: how the server serves the badge cheaply (New or Confirmed, date at or before shop day, any age); open orders exempt from the 90-day rule. | Closed: superseded by PRD v1.6 (no Unfinished view); the badge count stays and is built (architecture 16 section 32.4). [v1.8 | 2026-11-01] |
| TQ-13 | New-device notice without blocking sign-in. | Closed: built (architecture 16 section 32.4). [v1.8 | 2026-11-01] |

### 12.4 Design answers

Q-D1 (recovery way-in always shown) is void (Q-25 accepted). Q-D2 accepted (Complete asks one confirmation, FR-17). Q-D3 stays with the design owner. Q-D4 (staff account button) stays, with sign-out only plus "Sign out all other phones" (FR-4). [v1.5 | 2026-10-31]

## 13. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 to 1.4 | 2026-10-31 | First version, owner answers Q-1 to Q-14, approval of v1.2, review findings, Unfinished view and new-device notice. Full text of those versions is in git history. |
| 1.5 | 2026-10-31 | Simplification review after the owner directive that all apps be easy for every kind of user. New "How a day works" (01 section 0). Rewritten: 52 FRs to 27, 28 BRs to 14, 103 ACs to 48; old ids in 08 section 15. Deferred list in 08 section 14. Proposals changing owner decisions: P-1 recovery (Q-25), P-2 device list (Q-26), P-3 Unfinished view, chip, banner (Q-27), P-4 four cancel reasons (Q-28). Invisible-by-design: code and session limits, record, 90-day rule, review account. Q-23 withdrawn. New questions Q-25 to Q-28; TQ-10 to TQ-13 revised. |
| 1.7 | 2026-11-01 | Clarifications to match the built system (defect report X-1 to X-4): FR-7, BR-13 and AC-12 say "a phone on which the owner has no signed-in session at that moment" and add the sign-out-then-in example; stale labels removed ("Decided P-2", "proposed", PRD v1.5 headers); TQ-9 closed; BR-11 and AC-40 point to the new open question Q-29 (free delivery, non-blocking, recommendation: allow 0). No other requirement changed; ids and counts unchanged. |
| 1.8 | 2026-11-01 | Technical questions TQ-5, TQ-6, TQ-7, TQ-8, TQ-11 and TQ-13 closed as built, TQ-12 closed as superseded by v1.6, all pointing to docs/system/architecture/16-review-account-final-alignment.md section 32.4. TQ-1, TQ-2 and TQ-3 stay open with a status line each. No requirement changed; ids and counts unchanged. |
| 1.9 | 2026-11-02 | Owner input of 2026-11-02 recorded: Q-29 answered (fee known only when delivery starts), simple five-step process, no cancel once "being made". New part 09 with conflicts C-1 to C-8 against earlier owner decisions (PO BR-3, BR-2, FR-17, FR-18, AC-28 and others), impact list, new questions Q-30 to Q-36. No FR, BR or AC rewritten yet; old rules stay until the owner answers. |
| 1.11 | 2026-11-02 | Owner approved on 2026-11-02 (explicit answer) every id that was Pending owner approval in v1.10 (admin-orders.md status, Place Order v1.8). Q-37 and Q-38 answered and applied in BR-9 and BR-15 as decisions; Q-35 and Q-36 stay Assumed, to confirm. No other change. |
| 1.10 | 2026-11-02 | Owner answers of 2026-11-02 applied (Q-30 to Q-34 answered; Q-35, Q-36 recorded as assumptions to confirm; new Q-37, Q-38). Rewritten: BR-2, BR-8, BR-9, BR-11; FR-9, FR-10, FR-13, FR-14, FR-16 to FR-19, FR-23; AC-26 to AC-29, AC-37, AC-40, AC-41. New: BR-15, FR-28, FR-29, AC-49 to AC-52. C-1 to C-8 closed (09). Place Order v1.7 follows. Changed ids are Pending owner approval (admin-orders.md status). |
| 1.6 | 2026-10-31 | Owner accepted P-1 to P-4 (Q-25 to Q-28, all option a) on 2026-10-31. Status Approved. Q-25 to Q-28 closed as decided; Deferred list confirmed; PROPOSAL marks removed. No requirement text changed otherwise; ids and counts unchanged (27 FRs, 14 BRs, 48 ACs). |
