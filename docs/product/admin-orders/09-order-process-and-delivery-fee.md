# Admin Orders: Order Process and Delivery Fee Change (section 16)

Part of [Admin Orders](../admin-orders.md) (PRD v1.10). Holds: the owner input of 2026-11-02, the new simple order process, the conflicts with earlier owner decisions (all closed in v1.10), and the impact for other agents. New in v1.9 [v1.9 | 2026-11-02]. On 2026-11-02 the owner answered Q-30 to Q-34 and the affected FR, BR and AC were rewritten in place (old wording marked "Superseded 2026-11-02"); Q-35 and Q-36 are assumptions to confirm; new Q-37 and Q-38 are open and non-blocking (07). [v1.10 | 2026-11-02]

Status of conflicts [v1.10 | 2026-11-02]: C-1 to C-8 are all Resolved 2026-11-02. C-1 and C-6: customer sees an estimate and the cakes total; real fee at handover (Q-30, Q-31; BR-15, PO BR-3, PO BR-5, PO FR-9, PO AC-11, PO AC-14). C-2 and C-3: district fee is an estimate, real fee per order, 0 allowed (Q-33; BR-11, FR-23, FR-29, AC-37, AC-40, AC-41, AC-50). C-4 and C-5: six steps, cancel only through Processing, Finished only after Delivery started (Q-32, Q-34; BR-2, BR-8, FR-16 to FR-19, AC-26 to AC-29). C-7: the customer date stays as the requested date and holds capacity, the expected date is information only (Q-36 assumed; BR-15, FR-28, AC-49). C-8: all open steps are unfinished (Q-36 assumed; BR-9, FR-13, AC-52). The tables below keep the original wording as history.

## 16. Owner input of 2026-11-02

Verbatim intent (Vietnamese, business input): "Q29 phi giao hang: chi khi bat dau qua trinh giao moi biet chi phi. Quy trinh don gian: Nhan don -> xu ly don (khoang 1 ngay) -> hen ngay giao (du kien, co the thay doi chenh lech khoang 1-2 day) -> bat dau giao -> ket thuc. Cac quy trinh huy khac co the tuy tinh hinh, neu da o buoc dang lam thi khong the huy (vi co the banh se khong co ai nhan)." [v1.9 | 2026-11-02]

### 16.1 What the owner decided

| # | Decision | Status |
| - | -------- | ------ |
| OD-1 | Q-29 is answered: the delivery fee is not known when the order is placed; it becomes known only when delivery starts. [v1.9 | 2026-11-02] | Decided |
| OD-2 | Simple process, five steps: Received, Processing (about 1 day), Delivery date scheduled (expected only; it may move by about 1 to 2 days), Delivery started, Finished. [v1.9 | 2026-11-02] | Decided |
| OD-3 | Cancelling depends on the situation. Once the order is in the "being made" step it cannot be cancelled, because the cake may have no recipient. [v1.9 | 2026-11-02] | Decided; which step is "being made" is open (Q-32) |

Mapping assumed until answered (recommendation, not a decision): Received = New; Processing = Confirmed (about 1 day); then three new steps between Confirmed and Completed; Finished = Completed. [v1.9 | 2026-11-02]

### 16.2 Conflicts with earlier owner decisions (kept visible, to resolve)

| ID | Earlier rule (owner decided) | New input | Resolution |
| -- | ---------------------------- | --------- | ---------- |
| C-1 | PO BR-3, PO Q-5 (2026-10-25): flat fee per district, no free delivery; PO AC-11: the fee for the district is shown when the district is chosen. | The fee is unknown until delivery starts. | Conflict. Needs Q-30 and Q-31. PO BR-3, PO BR-5 (total = cakes + fee), PO FR-9, PO AC-11, PO AC-14 stay in force until answered. |
| C-2 | BR-11, FR-23, AC-37, AC-41: the owner sets a fee per district; orders keep the fee stored at order time. | The real fee is entered later, per order. The district fee can become only an estimate or disappear. | Conflict. Needs Q-30, Q-31, Q-33. |
| C-3 | AC-40 and BR-11: fee 0 refused (open as Q-29). | Q-29 is answered in a different way: the question changes from "allow 0" to "when is the fee known". | Q-29 closed as answered; whether 0 is allowed for the real fee is new Q-33. |
| C-4 | BR-2: only four changes (New to Confirmed, New to Cancelled, Confirmed to Completed, Confirmed to Cancelled); FR-16 to FR-19, AC-26 to AC-29. | Three new steps (date scheduled, delivery started, finished) sit between Confirmed and Completed. | Conflict. BR-2 would need new transitions; Q-8 "Complete any time after Confirmed" (FR-17, AC-27) conflicts with "Finished only after delivery started". Needs Q-32, Q-34. |
| C-5 | FR-18, AC-28, BR-8: staff and owner may cancel any New or Confirmed order; reasons list (four). | Cancel not possible in the "being made" step. | Partial conflict: if "being made" is Confirmed, then Confirmed orders can no longer be cancelled, against AC-28 ("Confirmed orders cancel the same way"). Needs Q-32, Q-35. |
| C-6 | PO FR-9 and PO AC-14: total on review and confirmation; AC-41 (admin): order shows total 260 000 with fee. | Total is not final at order time. | Follows C-1; the total shown to the customer and staff must change. Needs Q-30, Q-31. |
| C-7 | PO delivery date: customer picks a date and slot, held against the daily limit (PO BR-9, BR-2 here). | Delivery date is "scheduled" later by the shop and is only expected, may move 1 to 2 days. | Conflict or add-on: unclear whether the customer-chosen date stays as a request. The daily limit counts the customer date today. Needs Q-34, Q-36. |
| C-8 | BR-9 (90-day window, finished orders only; open orders exempt; unfinished = New or Confirmed with date at or before today; red marks, badge). | New steps are open steps. | Not a conflict in intent, but the definition of "unfinished", the badge and red marks must name the new steps. Needs Q-36. |

### 16.3 Existing items changed or contradicted

Statuses: New, Confirmed, Completed, Cancelled (BR-2, FR-14, FR-16 to FR-19, PO overview line 26) would grow by three steps. ACs touched: AC-26 to AC-29, AC-37, AC-40, AC-41, AC-48 (Delivery entry), AC-11 and AC-14 (PO). Screens touched: A1 to A4 reference screens (list, detail, status actions, Delivery settings), customer address step, review and confirmation screens. All of the above were rewritten in v1.10 [v1.10 | 2026-11-02]; AC-48 (Settings entries) needs no change.

### 16.4 Impact for other agents (they write their own documents)

| Agent | Impact |
| ----- | ------ |
| canvas-ui | Detail screen: step indicator for five steps; actions per step; field for the expected delivery date and for the real fee; cancel hidden or disabled in the "being made" step with Vietnamese copy; list status labels and filters; customer review and confirmation screens: how the fee line reads (estimate, "to be told") and the total; Delivery settings copy if district fees become estimates. |
| atlas-architect | Status model and transition table (docs/system/order-lifecycle.md), new fields (expected delivery date, real fee, fee entered by and when), whether the stored district fee stays, total definition, API (new transitions, fee entry, date change, stale-view rules), migration of existing orders and old statuses, record (BR-3) for date moves, capacity rule if the date moves, notification content. |
| forge-dev | Backend transition checks, new endpoints, migration, admin and customer apps (iOS, Android), contracts and fixtures, 90-day and unfinished queries. |
| probe-qa | Rewrite or add tests for AC-26 to AC-29, AC-37, AC-40, AC-41, PO AC-11, PO AC-14, PO AC-28, PO AC-35, PO AC-36; new matrix of transitions and cancel by step; fee known only at delivery start; date move of 1 to 2 days. |
