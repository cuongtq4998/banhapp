# Place Order: Order Tracking in the Customer App (section 14)

Part of [Place Order](../place-order.md). Status: **Draft, pending owner approval** (it adds scope: it replaces the non-goal "Order tracking, status display" of 01). New in v1.9 [v1.9 | 2026-11-02]. Source: owner decision 4 of 2026-11-02 (explicit answer): the customer sees the expected delivery date and the real fee after ordering, through a NEW order tracking screen in the customer app. Everything below that is not that sentence is a recommended default, marked "(default)", and needs the owner (14.6). Process and fee rules: Admin Orders BR-2, BR-11, BR-15, BR-16, BR-17.

## 14.1 Superseded text

| Old text | Now |
| -------- | --- |
| 01 non-goal "Order tracking, status display or cancellation in the app" | Tracking and status display are in scope once this part is approved; cancellation by the customer stays out (Admin Orders BR-16). Until approval the old non-goal holds. [v1.9 | 2026-11-02] |
| AC-15 "no tracking or cancel option" on the confirmation screen | The confirmation screen may add one action "Follow this order" (FR-22). No cancel option. Until approval AC-15 holds. [v1.9 | 2026-11-02] |

## 14.2 Functional requirements (Draft)

| ID | Requirement | Priority |
| -- | ----------- | -------- |
| FR-22 | The system shall show the customer an order tracking screen for an order placed in the app: order code, cakes and cake total, requested date and slot, the status in the five steps (Received, Processing, Delivery date scheduled, Delivery started, Finished) with the current step marked, or "Cancelled". [v1.9 | 2026-11-02] | Must |
| FR-23 | The screen shall show the expected delivery date once staff set it (Admin Orders FR-28), labelled as expected and as possibly moving by a few days, together with the requested date; before it is set it says the shop will schedule it after processing (about 1 day). [v1.9 | 2026-11-02] | Must |
| FR-24 | Until the real fee is entered (Admin Orders FR-29) the screen shall show the district fee as an estimate with the text that the final fee is told at delivery, and no total with fee. After it, the screen shall show the real fee (free delivery when 0) and the amount to collect = cakes + real fee. When staff correct the fee (Admin Orders FR-30) the screen shows the corrected fee and amount, without any mention of the old one. [v1.9 | 2026-11-02] | Must |
| FR-25 | The customer shall reach the screen (default): (a) from the confirmation screen, (b) from a list "My orders" of the orders placed on this phone, (c) by entering the order code and the phone number used. No sign-in. [v1.9 | 2026-11-02] | Must |
| FR-26 | The screen shall read the current state each time it opens and on a pull-to-refresh, and say when the data was read; there is no push message to customers (default). Without a connection it shows the last data read, with its time, and an offline notice. [v1.9 | 2026-11-02] | Must |
| FR-27 | For a Cancelled order the screen shall show "Cancelled" and the shop contact (Call, Zalo), and no reason. The customer has no cancel action and no refusal action; for a problem the screen points to the shop contact. [v1.9 | 2026-11-02] | Should |

## 14.3 Business rules (Draft)

| ID | Rule |
| -- | ---- |
| BR-15 | Source of truth. The screen shows what the shop recorded; nothing on it can be edited or confirmed by the customer. Values follow Admin Orders BR-11 and BR-15 (estimate versus real fee; expected date is information only and does not move the requested date). [v1.9 | 2026-11-02] |
| BR-16 | Visible data (default; owner decides, Q-O10). Shown: order code, cake names, quantities, prices, requested date and slot, expected date, district, status, fee and amounts, shop contact. Not shown: other customers' data, cancel reason, staff names, internal records (Admin Orders BR-3, BR-8). Phone and address appear masked (last 3 digits of the phone; district only). [v1.9 | 2026-11-02] |
| BR-17 | Lookup by code and phone (default). Both must match; a wrong pair gives one message that does not say which part was wrong; at most 5 wrong tries per phone per hour, then a short wait message. The code alone never opens an order. [v1.9 | 2026-11-02] |
| BR-18 | How long (default, Q-O8). An order is shown while open and for 30 days after Finished or Cancelled, then it is not shown or found. This follows PO BR-12 retention, which is still open (Q-O4); the stricter value applies. [v1.9 | 2026-11-02] |

## 14.4 Acceptance criteria (Draft)

| ID | Covers | Criterion |
| -- | ------ | --------- |
| AC-38 | FR-22 | Given an order at Processing, when the customer opens the screen, then step 2 of 5 is marked, step 1 is shown as done, and the code, cakes (2 x 120 000 = 240 000), requested date 10/11 and slot are shown. [v1.9 | 2026-11-02] |
| AC-39 | FR-23 | Given no expected date, the screen says the shop will schedule it after processing and shows only the requested date 10/11. Given expected date 12/11, it shows "Expected 12/11" with the note that it may move, and the requested date 10/11. When staff change it to 13/11 and the customer refreshes, it shows 13/11. [v1.9 | 2026-11-02] |
| AC-40 | FR-24 | Given district fee 20 000 and no real fee, the screen shows "Delivery fee: about 20 000 (final fee told at delivery)" and no amount to collect. Given real fee 25 000, it shows fee 25 000 and amount to collect 265 000 for cakes 240 000; with real fee 0 it shows free delivery and 240 000. [v1.9 | 2026-11-02] |
| AC-41 | FR-24 | Given the fee corrected from 25 000 to 30 000 while Delivery started, when the customer refreshes, then the screen shows 30 000 and 270 000, and nowhere 25 000. [v1.9 | 2026-11-02] |
| AC-42 | FR-22 | Given Finished, all five steps are done and the screen says finished; no action is offered. [v1.9 | 2026-11-02] |
| AC-43 | FR-27 | Given a Cancelled order with reason "fake or spam order", the screen shows "Cancelled" and the shop contact, and the reason text appears nowhere on screen or in the data sent to the phone. No cancel or refusal button exists at any step. [v1.9 | 2026-11-02] |
| AC-44 | FR-25, BR-17 | Given a right code and phone, the order opens. Given a right code and a wrong phone, or a wrong code, the same message appears. Given 5 wrong tries in an hour, the 6th is refused with a wait message even if correct. [v1.9 | 2026-11-02] |
| AC-45 | FR-25 | Given 2 orders placed on this phone, "My orders" lists both, newest first, each with code and status. Given none, it shows an empty state with the lookup by code and phone. [v1.9 | 2026-11-02] |
| AC-46 | FR-26 | Given the connection is lost after opening, the last data stays with its read time and an offline notice; no error screen. After the connection returns and a refresh, the data is current. No push message is sent to the customer at any status or date change. [v1.9 | 2026-11-02] |
| AC-47 | BR-16, BR-18 | The phone shows as "0900 000 ***" (fake sample), the address as the district only. An order Finished 31 days ago is not listed and not found. No staff name, record or reason appears. [v1.9 | 2026-11-02] |

## 14.5 Non-functional and dependencies

Texts in Vietnamese as the other customer screens; read-only, one screen plus the list and the lookup form. A customer endpoint that reads an order by code and phone is new customer-data exposure (security: escalation case). Push to customers would need a push service and Apple and Google accounts that the owner has not approved (money and account); not in this part. [v1.9 | 2026-11-02]

## 14.6 Questions for the owner (one batch; recommended default first)

| ID | Question | Blocking | Type | Default |
| -- | -------- | -------- | ---- | ------- |
| Q-O6 | How does the customer find the order: code plus phone, a link, or the list of orders on this phone? | Yes | business | All of: confirmation screen, list on this phone, code plus phone (FR-25). No link (needs links and hosting set-up). |
| Q-O7 | Must the customer sign in? | Yes | business | No. Same as ordering today (no account). |
| Q-O8 | How long after Finished or Cancelled is the order shown? | No | business | 30 days (BR-18). |
| Q-O9 | Is the customer told when the status or date changes? A push to customers needs a push service plus Apple and Google accounts (money and accounts, not approved). | Yes | business and money | No push. The customer opens or refreshes the screen (FR-26). Staff keep calling as in Admin Orders Q-35. |
| Q-O10 | Which personal data is visible, and to whom? | Yes | security | Masked phone, district only, no reason or staff names (BR-16); only the person with the code and the matching phone. |
| Q-O11 | What does the customer see for a cancelled order and the reason? | No | business | "Cancelled" plus shop contact; no reason (BR-8 keeps it internal). |
| Q-O12 | Should the confirmation screen offer "Follow this order" (changing AC-15)? | No | business | Yes. |
