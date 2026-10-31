# Admin Orders: Open Questions and Change Log (sections 12 and 13)

Part of [Admin Orders](../admin-orders.md) (PRD v1.0). Holds: Q-1 to Q-14 (business, one batch for the owner), TQ-1 to TQ-5 (technical, for the architect), the change log.

## 12. Open Questions

All business questions are in this one batch. Each has a recommended option; if the owner does not object to a non-blocking question, the recommendation applies. Q-1 to Q-3 block approval.

### 12.1 Business questions (for the product owner)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| Q-1 | Should the admin features live in a separate admin app (recommended) or inside the customer app behind a staff sign-in? | Shape of everything; hard to reverse (store records, users). See D-1. | Yes | business | Open | Recommended: separate app, same repository and backend. |
| Q-2 | Which phones do the owner and staff use? Build for one platform first (recommended) or both iOS and Android at once? | Build and test effort roughly doubles for two platforms. See D-2. | Yes | business | Open | Recommended: one platform first, the one the owner and staff use; Android first if there is no preference (about 60 percent of Vietnam, S-4). |
| Q-3 | Do you approve paying for text messages that carry the sign-in codes? Expect roughly 200 to 500 VND per message (vendor figures, S-1), a sender-name registration with documents and a wait of weeks to months, and a monthly ceiling you set. Alternative: no sign-in code and a different method (needs a new decision). | Money; the architect cannot build sign-in without it (docs/system/auth.md). | Yes | business | Open | Recommended: approve, with a monthly ceiling (for example 200 000 VND) and the limits in BR-5. With 10 people and 30-day sign-ins, expect well under 100 messages a month. |
| Q-4 | How long should a phone stay signed in before a new code is needed? | Security against convenience; each new code costs money. | No | business | Open | Recommended: 30 days (BR-6). |
| Q-5 | Is one owner plus up to 10 staff enough? Do you need a second owner? | Rights and the lost-phone risk. | No | business | Open | Recommended: one owner, up to 10 staff (BR-8). |
| Q-6 | May the owner add or delete cakes, or only edit and hide the four existing ones? Photos are not editable in the app either way. | The customer app is designed for at most four cakes with fixed photos. | No | business | Open | Recommended: edit and hide only (FR-22, BR-11). New cakes and photos come through a developer. |
| Q-7 | Which ordering rules should the owner change in the app: only the daily limit (recommended), or also lead days (2), minimum cakes per order (2) and booking horizon (30 days)? | More switches mean more ways to misconfigure; these values were decided as fixed business rules. | No | business | Open | Recommended: daily limit only (FR-24); the other three stay fixed. |
| Q-8 | May staff mark an order Completed only on or after its delivery date, or at any time once Confirmed? | Prevents mistaken taps against flexibility. | No | business | Open | Recommended: any time once Confirmed (BR-2). |
| Q-9 | Should cancelling ask for a reason (for example "customer asked", "no stock")? | Records, but adds a step. | No | business | Open | Recommended: no reason in this slice (FR-18 only needs a confirmation). |
| Q-10 | Do staff need to edit an order (date, address, cakes) instead of cancelling it? | Editing needs capacity, price and rule checks again, which is a larger feature. | No | business | Open | Recommended: no; cancel and let the customer order again (non-goal). |
| Q-11 | Should every signed-in person get every new-order notification, and should a reminder follow if an order stays New? | Who is woken up and how often. | No | business | Open | Recommended: everyone signed in gets each new order; no reminders in this slice. |
| Q-12 | Do cancelled orders count toward the limit of 5 orders per phone per 24 hours? (Place Order Q-O3, now live because staff can cancel.) | A customer whose order was cancelled by the shop could be blocked from reordering. | No | business | Open | Recommended: cancelled orders do not count. |
| Q-13 | Should staff see all past orders, or only orders from the last N days? | Privacy of customer data against usefulness. | No | business | Open | Recommended: all orders until contact data is erased under the retention period (Place Order Q-O4, still open). |
| Q-14 | If the owner loses the phone or changes the number, is it acceptable that recovery is done by the system operator (a developer), outside the app? | Security of the one account that can change prices and staff. | No | business | Open | Recommended: yes for this slice (A-7). |

### 12.2 Technical questions (for the architect, not for the owner)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| TQ-1 | Which text-message provider and sender registration, and how are codes delivered in test and in the weeks before registration completes? | S-1 lead time may delay launch. | No | technical | Open | |
| TQ-2 | How is the admin app delivered to a small audience on each platform (unlisted release, test tracks, managed distribution)? | Depends on Q-1 and Q-2; S-2, S-3. | No | technical | Open | |
| TQ-3 | Which push service and what delivery guarantees; token handling when a device signs out or an account is deactivated? | FR-31, FR-35, G-1. | No | technical | Open | |
| TQ-4 | Session and credential design, creation of the first owner account (A-2), and the 1-minute revocation target (G-4). | FR-4, FR-7, AC-14. | No | technical | Open | |
| TQ-5 | How are stale-view conflicts detected for status changes, and what indexing serves list, filter and search at the expected volume (A-5)? | FR-19, FR-8 to FR-11. | No | technical | Open | |

## 13. Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-31 | First version (Draft). Covers the staff and owner scope left out of Place Order v1.5. |
