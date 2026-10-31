# Admin Orders: Open Questions and Change Log (sections 12 and 13)

Part of [Admin Orders](../admin-orders.md) (PRD v1.1). Holds: Q-1 to Q-17 (business), TQ-1 to TQ-10 (technical, for the architect), the change log. Changed or new lines end with [v1.1 | 2026-10-31].

## 12. Open Questions

Q-1 to Q-14 were answered by the owner on 2026-10-31 and are closed. Three new, non-blocking questions (Q-15 to Q-17) each have a recommended option that applies if the owner does not object. [v1.1 | 2026-10-31]

### 12.1 Business questions (for the product owner)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-1 | Separate admin app or inside the customer app? | Shape of everything. | No | business | Decided v1.1 | Separate admin app, same repository and backend (D-1). [v1.1 | 2026-10-31] |
| Q-2 | One platform first or both? | Build effort. | No | business | Decided v1.1 | iOS and Android at the same time (D-2). [v1.1 | 2026-10-31] |
| Q-3 | Pay for text messages that carry sign-in codes? | Money. | No | business | Decided v1.1 | No SMS. Sign-in is by e-mail plus a one-time code (FR-1 to FR-3, BR-5). Closed without a money decision; e-mail cost is low (S-5). [v1.1 | 2026-10-31] |
| Q-4 | How long does a phone stay signed in? | Security against convenience. | No | business | Decided v1.1 | 7 days with a short-lived access credential and a 7-day renewal credential, rotated on use; reuse of an old one signs that device out. The owner can revoke a device or deactivate staff: data access ends within minutes, renewal at once (BR-6, BR-8, FR-36, FR-37). Whether the 7 days restart on each use is asked in Q-15. [v1.1 | 2026-10-31] |
| Q-5 | How many owners and staff? | Rights, recovery risk. | No | business | Decided v1.1 | One owner and up to 30 staff (BR-8). [v1.1 | 2026-10-31] |
| Q-6 | May the owner add or delete cakes? | Customer catalog, history. | No | business | Decided v1.1 | Yes: add (name, description, price, image) and remove; removed means hidden from the customer app and kept in order history; at least one active cake must remain (FR-38, FR-39, BR-11, BR-18, BR-19). Maximum number of cakes is asked in Q-17. [v1.1 | 2026-10-31] |
| Q-7 | Which ordering rules may the owner change? | Misconfiguration risk. | No | business | Decided v1.1 | Daily limit, lead days and minimum cakes per order; booking horizon stays fixed. A change applies to new orders only (FR-24, FR-40, BR-21). [v1.1 | 2026-10-31] |
| Q-8 | When may staff mark Completed? | Mistaken taps against flexibility. | No | business | Decided v1.1 | Any time after Confirmed (FR-17, BR-2). [v1.1 | 2026-10-31] |
| Q-9 | Should cancelling ask for a reason? | Records. | No | business | Decided v1.1 | Yes, chosen from a fixed list of five (FR-18, BR-16). [v1.1 | 2026-10-31] |
| Q-10 | Do staff need to edit orders? | Larger feature. | No | business | Decided v1.1 | No editing; cancel and the customer orders again (non-goal). [v1.1 | 2026-10-31] |
| Q-11 | Who gets new-order notifications; reminders? | Who is woken up. | No | business | Decided v1.1 | Everyone signed in gets each one; no reminders (FR-31). [v1.1 | 2026-10-31] |
| Q-12 | Do cancelled orders count toward the 5 orders per phone per 24 hours? (Place Order Q-O3) | A customer cancelled by the shop could be blocked. | No | business | Decided v1.1 | Not counted, except cancellations with the reason "fake or spam order" (FR-44, BR-16). Changes the place-order backend rule (section 9). [v1.1 | 2026-10-31] |
| Q-13 | Which past orders may staff see? | Privacy against usefulness. | No | business | Decided v1.1 | Last 90 days; older orders are not shown. Same for the owner (BR-20, FR-41). [v1.1 | 2026-10-31] |
| Q-14 | Recovery if the owner loses the phone? | Security of the one powerful account. | No | business | Decided v1.1 | The owner registers a backup e-mail; on a new device sign-in needs codes sent to the owner e-mail and the backup e-mail; then the old device can be revoked (FR-42, FR-43, BR-17). Form of the codes asked in Q-16. [v1.1 | 2026-10-31] |
| Q-15 | Does the 7-day sign-in restart each time the app is used (a device used at least weekly never asks for a code), or end 7 days after the code was entered no matter what? | Convenience against security. | No | business | Open | Recommended: restart on each use (BR-6), because rotating the renewal credential on use already implies it. If the owner prefers a hard 7 days, staff enter a code every week. [v1.1 | 2026-10-31] |
| Q-16 | For owner recovery, are two different codes (one to each e-mail, both entered) acceptable, or should one code be sent to both addresses? | Security of recovery; one shared code gives no more protection than one mailbox. | No | business | Open | Recommended: two different codes, both entered (BR-17). [v1.1 | 2026-10-31] |
| Q-17 | What is the largest number of cakes the shop should hold (active and hidden)? | The customer catalog was designed for four cakes. | No | business | Open | Recommended: 12 (BR-18). [v1.1 | 2026-10-31] |

### 12.2 Technical questions (for the architect, not for the owner)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| TQ-1 | Which e-mail delivery service and sender-domain set-up, and how are codes delivered in test? Changed in v1.1 from text messages. | Deliverability (spam folders) decides whether sign-in works. [v1.1 | 2026-10-31] | No | technical | Open | |
| TQ-2 | How is the admin app delivered to a small audience on both platforms (unlisted release, test tracks, managed distribution)? | Q-1, Q-2 decided; S-2, S-3. [v1.1 | 2026-10-31] | No | technical | Open | |
| TQ-3 | Which push service and what delivery guarantees; token handling when a device signs out, is revoked or an account is deactivated? | FR-31, FR-35, G-1. | No | technical | Open | |
| TQ-4 | Session design: access and renewal credential lifetimes (access loss within 5 minutes, BR-8), rotation and reuse handling, revocation per device, creation of the first owner account (A-2). | FR-4, FR-7, FR-36, FR-37, AC-14, AC-53 to AC-55. [v1.1 | 2026-10-31] | No | technical | Open | |
| TQ-5 | How are stale-view conflicts detected for status changes, and what indexing serves list, filter and search at the expected volume (A-5)? | FR-19, FR-8 to FR-11. | No | technical | Open | |
| TQ-6 | Image upload for new cakes: accepted formats and size checks, storage, resizing, how the customer app loads them. | FR-38, BR-18, AC-60, AC-61. [v1.1 | 2026-10-31] | No | technical | Open | |
| TQ-7 | How is the 90-day window enforced (list, search, detail, notification tap) and how does it relate to the retention period (Place Order Q-O4)? | FR-41, BR-20. [v1.1 | 2026-10-31] | No | technical | Open | |
| TQ-8 | How is the place-order limit rule changed to ignore cancelled orders except reason "fake or spam order", and how is the cancel reason stored? | FR-44, BR-16; cross-feature with Place Order. [v1.1 | 2026-10-31] | No | technical | Open | |
| TQ-9 | How is a device identified and named for the device list, and how are removed cakes kept for history while hidden from the catalog? | FR-37, FR-39, BR-19. [v1.1 | 2026-10-31] | No | technical | Open | |
| TQ-10 | How are the two recovery codes, the backup e-mail confirmation and the recovery notice built and rate-limited? | FR-42, FR-43, BR-17. [v1.1 | 2026-10-31] | No | technical | Open | |

## 13. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version (Draft). Covers the staff and owner scope left out of Place Order v1.5. |
| 1.1 | 2026-10-31 | Owner answers Q-1 to Q-14 recorded. D-1 and D-2 became decisions. Phone-number and text-message sign-in replaced by e-mail plus one-time code everywhere (FR-1 to FR-3, FR-27, BR-5 to BR-8, AC-1 to AC-12, AC-42, AC-43, NFR, dependencies, A-7, A-8, TQ-1); SMS sources S-1 reduced (removed in v1.1), S-5 and S-6 added. New FR-36 to FR-44 (renewal credential rotation, device revoke, 90-day window, backup e-mail, recovery, add and remove cake, ordering rules, effect on Place Order); changed FR-7, FR-14, FR-17, FR-18, FR-20, FR-22, FR-31, FR-35. New BR-16 to BR-21; changed BR-1, BR-2, BR-4 to BR-9, BR-11, BR-12, BR-15. New AC-53 to AC-72; changed AC-1 to AC-4, AC-7 to AC-10, AC-12, AC-14, AC-27 to AC-29, AC-31, AC-34, AC-42, AC-43, AC-52. New questions Q-15 to Q-17 and TQ-6 to TQ-10. Removed in v1.1: text-message sign-in, the money question Q-3, the non-goals "adding or deleting cakes" and "changing lead days and minimum quantity". Place Order Q-O3 answered (cross-feature impact in section 9). |
