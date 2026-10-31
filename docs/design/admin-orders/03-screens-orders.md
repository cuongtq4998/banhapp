# Admin Orders UI, part 3: S-A3 to S-A5, orders (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31]

### S-A3 Order list "To do"

- Purpose: see what has to be done and find any order; first screen after sign-in (FR-9 to FR-13). Entry: sign-in, tab 1, app start with a session, notification foreground toast. Exit: S-A4 (row tap), S-A13 (staff account button), S-A6 (owner tab). [v1.1 | 2026-10-31]
- Layout, top to bottom: large title `A_ORDERS_TITLE` (staff: with the red `TabBadge` number beside it and a round glass account button at the right, label `A_ACCOUNT_A11Y`); search `TextField` (`A_SEARCH_PLACEHOLDER`, clear button, search key); one control row: status chips (`FilterChip`, single choice, horizontal scroll) `A_FILTER_TODO` (default, selected), `A_STATUS_NEW`, `A_STATUS_CONFIRMED`, `A_STATUS_COMPLETED`, `A_STATUS_CANCELLED`, `A_FILTER_ALL`, then the date chip `A_FILTER_DATE`; list of `OrderRow`; tab bar (owner only) with the red `TabBadge` on Orders. [v1.1 | 2026-10-31]
- Row (FR-9, AC-15): code, customer name, status, delivery date and slot, number of cakes, total, district; no phone, address or note. When the order is New or Confirmed and the delivery date is today or earlier, the row shows the red `DueMark` after the date: `A_DUE_TODAY` or `A_OVERDUE` with `{n}` days. The app computes it from the order's delivery date and the server date of the same response (Vietnam time), not from the device clock; a row's mark does not change while the screen is open. Completed and Cancelled rows never show a mark (AC-16). [v1.1 | 2026-10-31]
- Order (BR-9, AC-14): as the server returns it, earliest delivery date, then slot, then oldest placed; the same for every filter. Overdue orders are therefore on top; there is no other overdue view, chip or banner. [v1.1 | 2026-10-31]
- Status filter (FR-10): exactly one chip is selected; tapping another replaces it; `A_FILTER_TODO` = all New and Confirmed of any date; `A_FILTER_ALL` = all four statuses. Date chip: a native menu (iOS `Menu`, Android `DropdownMenu`) with `A_DATE_ALL`, `A_DATE_TODAY`, `A_DATE_TOMORROW`, `A_DATE_ONE`; the last opens the native date picker (graphical dialog) for one date. The chip then reads "Hôm nay", "Ngày mai" or `dd/MM`; "today" and "tomorrow" follow the server date (AC-18). Any change reloads from the first page. No range, no multi-select. [v1.1 | 2026-10-31]
- Search (FR-11, BR-10, AC-19): starts at 3 typed characters or the search key; fewer than 3 shows `A_SEARCH_MIN`; combines with the chips; `A_SEARCH_HINT` is the help line when the field is focused and empty; up to 100 characters.
- Orders tab badge (FR-13, AC-17): red round number = New and Confirmed orders with delivery date today or earlier, taken from the same server answer as the list (a count field), not counted from the loaded rows; hidden at 0; "99+" above 99; refreshed on open, on pull-down, on return from background after more than 60 s, and right after each status change on S-A4/S-A5 without reopening the app. Screen-reader label `A_TAB_BADGE_A11Y`. Colour is never the only signal: the number is the signal. [v1.1 | 2026-10-31]
- Paging (BR-9, AC-23): 50 rows at a time; reaching the last 5 rows loads the next 50; the footer shows a spinner, or on failure `A_LOAD_MORE_FAILED` with a retry text button (earlier rows stay).
- Refresh (FR-12, AC-20): opening, returning from background after more than 60 s, and pull-to-refresh reload from the first page. No "last updated" line and no New counter.
- Actions: open an order; choose status; choose date; search; pull to refresh; open account (staff).
- States:
  - Default: rows as above.
  - Loading: five `OrderRow` skeletons; chips and search stay usable; on a refresh the old rows stay with the native indicator.
  - Empty: `StateView` `A_ORDERS_EMPTY` with `A_CLEAR_FILTERS` when a chip other than To do or a date is set; in To do with no date the text is `A_TODO_EMPTY` ("all done"); with a search term `A_SEARCH_EMPTY` (AC-19, AC-20). [v1.1 | 2026-10-31]
  - Error: `StateView` `A_ERR_GENERIC` and `A_RETRY`.
  - Offline: `StateView` `A_OFFLINE` and `A_RETRY`; no earlier rows shown as current (AC-20).
  - Disabled, Success: N/A.

### S-A4 Order detail

- Purpose: read one order and move it forward (FR-14 to FR-19). Entry: row tap; notification tap (AC-31). Exit: back to S-A3 (the list and the badge reload on return). [v1.1 | 2026-10-31]
- Layout, top to bottom: `TopBar` (title is the code, selectable) with `StatusBadge`; customer `GlassCard` (`A_SEC_CUSTOMER`: name, phone, `ContactButton` capsules `A_CALL` and `A_ZALO`, FR-15); delivery card (`A_SEC_DELIVERY`: weekday, date and slot, with the red `DueMark` when New or Confirmed and due; address, district); cakes card (`A_SEC_CAKES`: name, quantity, unit price, line total as stored, then `A_FEE` and `A_TOTAL`, AC-24); note card (`A_SEC_NOTE`, only if there is a note); cancel reason card (`A_SEC_REASON`, only if cancelled); two small lines: `A_PLACED_AT` and `A_LAST_CHANGED` ("Cập nhật lần cuối bởi {name}, {datetime}", name is `A_HIST_CUSTOMER` for an order not yet changed); `BottomActionBar`. No history list (deferred). [v1.1 | 2026-10-31]
- Action bar (FR-16 to FR-18): New: left `A_CANCEL_ORDER` (destructive), right `A_CONFIRM_ORDER`; Confirmed: left `A_CANCEL_ORDER`, right `A_COMPLETE_ORDER`; Completed and Cancelled: no bar. Confirm = one tap, no dialog (AC-26, AC-30). Complete = `ConfirmDialog` `A_COMPLETE_TITLE`/`A_COMPLETE_BODY` naming the code, buttons `A_COMPLETE_YES` and `A_BACK` (final action; allowed any time after Confirmed, AC-27). Cancel opens S-A5.
- Behaviour: after Confirm or Complete the badge, mark and bar update in place with `motion.spring.standard`, success haptic, `Toast` `A_STATUS_CHANGED`; the Orders tab number drops (S-A3). During the request the pressed button shows a spinner and the other is disabled. Call opens the dialer; Zalo opens the chat, else `Toast` `A_ZALO_UNAVAILABLE` (AC-25; ADR-0015). Phone is selectable text.
- Conflict (FR-19, AC-29): if the server refuses because the order changed, the screen reloads and shows the current status with `InlineMessage` (Warning) `A_CONFLICT` with `{status}`, error haptic; open sheets and dialogs close. A repeated change (double tap) is not an error: the screen simply shows the result.
- States:
  - Default: as above.
  - Loading: skeleton cards; bar hidden until the order is known.
  - Empty N/A. Order not found or past 90 days, also from a notification: `StateView` `A_ORDER_GONE` with `A_BACK_TO_LIST` (AC-21).
  - Error: `StateView` `A_ERR_GENERIC`, `A_RETRY`; a failed status action shows `InlineMessage` (Error) `A_ERR_STATUS` above the bar.
  - Offline: `StateView` `A_OFFLINE`, `A_RETRY`; on a status action `A_OFFLINE_SAVE`, status unchanged.
  - Disabled: the other bar button while one request runs. Success: status updated.

### S-A5 Cancel order (sheet)

- Purpose: cancel with one required reason (FR-18, BR-8). Entry: `A_CANCEL_ORDER` on S-A4. Exit: close or done.
- Layout: sheet title `A_CANCEL_TITLE`; text `A_CANCEL_BODY` naming `{code}` and saying the cakes go back to the delivery date (BR-2); `ReasonList` with exactly four reasons `A_REASON_CUSTOMER`, `A_REASON_CANNOT_DELIVER`, `A_REASON_NO_CONTACT`, `A_REASON_SPAM`, none preselected (AC-28); `PrimaryButton` destructive `A_CANCEL_CONFIRM` ("Hủy đơn {code}"), disabled until a reason is chosen; `SecondaryButton` `A_BACK` (status unchanged). This one screen is the whole cancel step: choose and confirm. [v1.1 | 2026-10-31]
- Behaviour: success closes the sheet, S-A4 shows Cancelled with the reason card, `Toast` `A_STATUS_CHANGED`. `A_REASON_INTERNAL` sits under the list.
- States: Default (nothing selected, confirm disabled); Loading (spinner in confirm); Empty N/A; Error (`InlineMessage` `A_ERR_STATUS`); Offline (`A_OFFLINE_SAVE`); Disabled (confirm until a reason); Success (close). Conflict as S-A4.
