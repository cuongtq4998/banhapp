# Admin Orders UI, part 12: Order process and delivery fee, screens (section 5, change of 2026-11-02)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). Based on PRD v1.10 (file `product/admin-orders/09-order-process-and-delivery-fee.md`). New in v1.4. This part replaces the order-status behaviour of S-A3 and S-A4 in part 3 and the cancel entry of S-A5; where the two differ, this part wins (part 3 carries a pointer). Copy, accessibility and test ids: [part 13](13-order-process-copy-a11y.md). [v1.4 | 2026-11-02]

## 5.12 Order steps and who can do what (FR-16 to FR-19, FR-28, FR-29, BR-2)

| Step (copy key) | Left action in the bar | Right action in the bar | Cancel | Note line under the cards |
| --------------- | ---------------------- | ----------------------- | ------ | ------------------------- |
| 1 Received `A_STATUS_RECEIVED` | `A_CANCEL_ORDER` | `A_PROCESS_ORDER` (one tap, no dialog) | allowed | none |
| 2 Processing `A_STATUS_PROCESSING` | `A_CANCEL_ORDER` | `A_SCHEDULE_DATE` (opens S-A14) | allowed | none |
| 3 Delivery date scheduled `A_STATUS_SCHEDULED` | `A_CHANGE_DATE` (secondary, opens S-A14 in change mode) | `A_START_DELIVERY` (opens S-A15) | hidden | `A_CANCEL_BLOCKED` |
| 4 Delivery started `A_STATUS_DELIVERING` | none | `A_FINISH_ORDER` (confirmation naming the code) | hidden | `A_CANCEL_BLOCKED` |
| 5 Finished `A_STATUS_FINISHED` | no bar | no bar | no | none |
| Cancelled `A_STATUS_CANCELLED` | no bar | no bar | no | reason card |

- Cancel decision: the button is removed (not greyed) from step 3 on, because a disabled button invites taps with no result and the bar then holds only forward actions. The reason is always visible as `InlineMessage` (Info) `A_CANCEL_BLOCKED` above the bar, so nobody has to guess. A direct refused request (old view, other person) uses the conflict message of S-A4. [v1.4 | 2026-11-02]
- Finish: `ConfirmDialog` `A_FINISH_TITLE` / `A_FINISH_BODY` with `{code}`, buttons `A_FINISH_YES` and `A_BACK`; offered only at step 4 (AC-27).
- Backward moves do not exist. The only repeatable change is the expected date at step 3 (FR-28).

## S-A4 Order detail (revised) [v1.4 | 2026-11-02]

- Layout, top to bottom: `TopBar` (code, selectable) with `StatusBadge`; `OrderStepper` card (new, see 5.15) for open and Finished orders; customer card (unchanged, FR-15); delivery card; cakes card; note card; cancel reason card (only when Cancelled); the two small lines `A_PLACED_AT` and `A_LAST_CHANGED`; `A_CANCEL_BLOCKED` message when it applies; `BottomActionBar` (5.12).
- Delivery card (FR-14): weekday, date and slot the customer asked for under label `A_REQUESTED_DATE`; from step 3 a second line `A_EXPECTED_DATE` in `type.body.strong` (the date staff set; tapping it opens S-A14 at step 3 only). The red `DueMark` follows the list date: the expected date when set, otherwise the requested date; shown for steps 1 to 4 when that date is today or earlier (BR-9, AC-52). Address and district as before.
- Cakes card (BR-15, AC-51): lines as stored; `A_CAKES_TOTAL` (sum of cakes); `A_FEE` row: before the real fee is entered the value is `A_FEE_PENDING` (text "Báo khi giao", muted, not a number) and the district estimate is shown under it as `A_FEE_ESTIMATE_LINE` ("Phí dự kiến theo quận: {amount}"); after entry the amount, or `A_FEE_FREE` for 0; `A_TOTAL_COLLECT` row ("Cần thu khi giao") appears only after the fee is entered. No total with fee exists before that. An order stored before the change keeps its stored fee and shows it as entered (migration is the architect's; question TQ-D9).
- Behaviour: the confirm of step 1 to 2 updates badge, stepper, bar in place with `motion.spring.standard`, success haptic, `Toast` `A_STATUS_CHANGED`. S-A14 and S-A15 close on success and the detail shows the new step and values; the Orders tab number is refreshed after every change (AC-17).
- Conflict (FR-19, AC-29): the server refuses a change made on an old view (including cancel after step 3, fee entry at the wrong step, a finished order): the screen reloads, shows `A_CONFLICT` with `{status}`, error haptic, sheets and dialogs close. A repeated change (double tap) shows the result without error and without a second record.
- States: Default as above. Loading: skeleton cards and stepper skeleton, bar hidden. Empty: N/A; gone order `A_ORDER_GONE`. Error: `A_ERR_GENERIC`, `A_RETRY`; failed action `A_ERR_STATUS` above the bar. Offline: `A_OFFLINE` or `A_OFFLINE_SAVE` on an action, status unchanged. Disabled: the other bar button during a request. Cancel blocked: see 5.12. Success: new step shown.

## 5.13 S-A14 Schedule delivery date (sheet), FR-28, AC-49

- Purpose: set the expected delivery date (step 2 to 3) and move it any number of times at step 3. Entry: `A_SCHEDULE_DATE` or `A_CHANGE_DATE` (or the tap on the expected date). Exit: close or save. [v1.4 | 2026-11-02]
- Layout: sheet title `A_SCHEDULE_TITLE` (or `A_RESCHEDULE_TITLE`); a reference card with the code, the customer's requested date and slot (`A_REQUESTED_DATE`) and, in change mode, the current expected date (`A_EXPECTED_DATE`); the native graphical date picker (iOS `DatePicker` graphical; Android `DatePicker` Material 3), shop time zone Asia/Ho_Chi_Minh as in S-A3, opening on the current expected date, else the requested date, else the server today; a caption `A_SCHEDULE_HELP` saying it is expected only and may change; bottom bar: `PrimaryButton` `A_SCHEDULE_SAVE` / `A_RESCHEDULE_SAVE`, `SecondaryButton` `A_BACK`. The pinned bottom bar and large detent follow S-A5.
- Date range [v1.5 | 2026-11-02]: owner decision. Only the server today to today + 7 (inclusive, 8 days) can be chosen; all other days are disabled (greyed, not selectable; native `DatePicker` `in:` range on iOS, `SelectableDates` on Android). Under the picker a fixed line `A_DATE_LIMIT_HELP` names the limit with the first and last allowed date. A disabled day read by a screen reader says it is unavailable. The picker opens on the current expected date if it is inside the range, else on the requested date if inside, else on today. If an old expected date is already past today it stays shown as text in the reference card; the person must pick a new day to save. Server refusals: 422 `EXPECTED_DATE_PAST` shows `A_ERR_DATE_PAST`, `EXPECTED_DATE_TOO_FAR` shows `A_ERR_DATE_TOO_FAR` as `InlineMessage` above the bar (happens after midnight or with a wrong phone clock); the picker range is recomputed from the server today.
- Rules: no reason is asked for a move (assumption, B-D2); in change mode the save button is disabled until the date differs from the current expected date (so no empty record); the shop daily limit is not shown or checked here because the expected date is information only (C-7, Q-36 assumed).
- Behaviour: save closes the sheet, the delivery card shows the new expected date, success haptic, `Toast` `A_DATE_SAVED`; the date change is recorded server side with the account and time (BR-3); `A_LAST_CHANGED` shows it. The customer-held capacity date is unchanged.
- States: Default (picker on the opening date, save enabled in schedule mode, disabled in change mode until changed); Loading (spinner in save, picker inert); Empty N/A; Error (`InlineMessage` `A_ERR_STATUS`); Offline (`A_OFFLINE_SAVE`); Disabled (save while unchanged or loading); Success (close); Conflict as S-A4 (the order moved on, for example to step 4).
- Landscape: no layout change; the sheet scrolls and the bottom bar stays pinned; the graphical picker may need scrolling above the bar.

## 5.14 S-A15 Start delivery and real fee (sheet), FR-29, AC-50

- Purpose: enter the real delivery fee and start delivery in one step (step 3 to 4). Entry: `A_START_DELIVERY`. Exit: close or confirm. [v1.4 | 2026-11-02]
- Layout: title `A_FEE_TITLE`; text `A_FEE_BODY` naming `{code}`; `TextField` `A_F_REAL_FEE` (whole dong, number pad, label above, `type.title` value, ` ₫` suffix, no prefill, so the person must type it; 0 is typed as 0); helper `A_FEE_ESTIMATE_LINE` with the district estimate; summary rows `A_CAKES_TOTAL`, the typed fee, `A_TOTAL_COLLECT` updating as the person types (empty field: fee row shows "-", total row hidden); bottom bar: `PrimaryButton` `A_START_DELIVERY_CONFIRM`, `SecondaryButton` `A_BACK`. Large detent, content scrolls above the keyboard, bar pinned (like S-A5).
- Validation (save-time and while leaving the field): empty `A_ERR_FEE_REQUIRED`; below 0, above 10 000 000 or not a whole number `A_ERR_FEE_RANGE`; the confirm button stays enabled so the errors can be listed (as the forms in part 4); nothing is changed when refused. Typing 0 is valid and the summary says `A_FEE_FREE`. No dialog after the sheet: the sheet is the confirmation, and starting delivery is not reversible by the app.
- Behaviour: success closes the sheet, detail shows step 4, the fee and the amount to collect, `Toast` `A_STATUS_CHANGED`, success haptic. Fee can be entered at no other step.
- States: Default (empty field, no errors); Loading (spinner in confirm); Empty (empty field is Default, error only after confirm); Error (field errors, `A_ERR_STATUS`); Offline (`A_OFFLINE_SAVE`); Disabled (confirm while loading); Success (close); Conflict as S-A4.
- Landscape: same layout; with the keyboard open the field and the total scroll above the bar.

## 5.15 `OrderStepper` (new component, proposal for design system part 7)

- A vertical list card of five rows (Received, Processing, Delivery date scheduled, Delivery started, Finished). Done row: filled circle with check, `color.brand`; current row: ring with dot plus bold label; later rows: grey outline. Next to the scheduled row it shows the expected date as secondary text once set; next to Finished and Delivery started nothing. Not interactive. Colour is not the only signal: icon shape and the label "Hiện tại" (`A_STEP_CURRENT`) mark the current row. Cancelled orders show no stepper (the badge and the reason card say it). Reduced motion: the current marker moves with a fade, not a slide. [v1.4 | 2026-11-02]
- Native base: plain SwiftUI `VStack` of `Label` rows (iOS) and Compose `Column` with Material icons (Android); no native stepper component exists for read-only progress (unverified: checked in Apple HIG and Material 3 component lists by name only, not by source).

## 5.16 S-A3 list changes (FR-9, FR-10, FR-13, BR-9, AC-52)

- Chips, in order (single choice, scrolls): `A_FILTER_TODO` (default), `A_STATUS_RECEIVED`, `A_STATUS_PROCESSING`, `A_STATUS_SCHEDULED`, `A_STATUS_DELIVERING`, `A_STATUS_FINISHED`, `A_STATUS_CANCELLED`, `A_FILTER_ALL`, then the date chip. "To do" = the four open steps of any date; "All" = all six states. [v1.4 | 2026-11-02]
- Row: status label is the new step name; the date shown is the list date: expected date as `A_ROW_EXPECTED` ("Dự kiến {dd/MM}") when set, else the requested date and slot; amount shown is the cake total (no total with fee in the row, since the fee may be unknown). The red `DueMark` (`A_DUE_TODAY`, `A_OVERDUE`) uses the list date and shows for the four open steps only; Finished and Cancelled never.
- Order (BR-9): list date, then slot, then oldest placed, as the server returns it. After a date move the row sits at its new place on the next refresh, not while the screen is open.
- Badge: counts open orders (four steps) with list date today or earlier; it is refreshed after every step change and date move.
- Date chip filters by the list date (assumption, question B-D3). Empty, loading, error, offline states unchanged; the empty "all done" text `A_TODO_EMPTY` stays.
- Landscape: unchanged (list rows reflow in width only).

## 5.17 S-A5 Cancel (change of entry)

Reached only at steps 1 and 2; the sheet and its four reasons are unchanged. If the order moved to step 3 or later while the sheet was open, confirm returns the conflict `A_CONFLICT`, the sheet closes. `A_CANCEL_BODY` still says the cakes go back to the requested date. [v1.4 | 2026-11-02]

## 5.19 S-A16 Correct delivery fee (sheet), FR-30, AC-53, AC-54 [v1.5 | 2026-11-02]

- Purpose: fix the real fee while the order is Delivery started (step 4). Entry: a secondary text button `A_FEE_CORRECT` on the fee row of the cakes card, shown only at step 4 for staff and owner. At Finished the fee row is read-only and the button is absent; the history list stays visible. Exit: close or save.
- Layout: title `A_FEE_CORRECT_TITLE` with `{code}`; row `A_FEE_PREVIOUS` with the current fee (read-only); `TextField` `A_F_REAL_FEE` (same rules as S-A15: whole dong, number pad, range 0 to 10 000 000, prefilled empty so a new value is typed; 0 allowed), summary rows `A_CAKES_TOTAL`, new fee, `A_TOTAL_COLLECT` updating while typing; bottom bar `PrimaryButton` `A_FEE_CORRECT_SAVE`, `SecondaryButton` `A_BACK`. Validation copy as S-A15 (`A_ERR_FEE_REQUIRED`, `A_ERR_FEE_RANGE`); a value equal to the current fee shows `A_ERR_FEE_SAME` and saves nothing (no empty record).
- History: on S-A4, below the cakes card, a card `A_FEE_HISTORY` listing corrections newest first: name, time `dd/MM HH:mm`, `A_FEE_CHANGE_LINE` ("{old} thành {new}"). Hidden when the list is empty (default state, no heading). The first entry of the fee itself is not a correction.
- Behaviour: success closes the sheet, the fee and total update in place, history gains a row, success haptic, `Toast` `A_FEE_CORRECTED`.
- Conflict (409): another device changed the fee or the order left step 4 after the view was loaded: sheet closes, the screen reloads, `A_FEE_CONFLICT` (`InlineMessage` Warning, names the new fee) shows, error haptic; nothing is overwritten. If the order is now Finished the correct button disappears.
- States: Default (empty field); Loading (spinner in save); Empty (history absent); Error (field errors, `A_ERR_STATUS`); Offline (`A_OFFLINE_SAVE`); Disabled (save while loading); Success (close); Conflict (above).
- Landscape: no layout difference; sheet scrolls, bar pinned, keyboard scrolls the field above the bar (same as S-A15).

## 5.18 S-A10 Delivery settings (copy change, FR-23, AC-37, AC-40)

The fee field is now the estimate: label `A_F_FEE` becomes `A_F_FEE_ESTIMATE`, note `A_FEE_EFFECT` becomes `A_FEE_EFFECT_ESTIMATE` (the estimate is shown to customers as an estimate; it does not change stored real fees); the district row shows the amount with `A_FEE_ESTIMATE_TAG`; an estimate of 0 is still refused (AC-40 lists "district estimated fee 0"), error `A_ERR_RANGE_INT` stays; only the real fee on S-A15 may be 0. [v1.4 | 2026-11-02]
