# Admin Orders UI, part 3: S-A4 to S-A7, orders (section 5)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31]

### S-A4 Order list

- Purpose: see and find orders; first screen after sign-in (FR-8 to FR-13, FR-41). Entry: sign-in, tab 1, app start with session, notification foreground tap on the banner. Exit: S-A6 (row tap), S-A5 (date chip), S-A19 (staff account button), S-A8 (owner tab).
- Layout, top to bottom: large title `A_ORDERS_TITLE` with the `CountPill` `A_NEW_COUNT` ("Mới: {n}") beside it and, for staff only, a round glass account button at the right (label `A_ACCOUNT_A11Y`); search `TextField` (`A_SEARCH_PLACEHOLDER`, clear button, search key); chip row (horizontal scroll): `FilterChip` "Tất cả" (`A_FILTER_ALL`), `A_STATUS_NEW`, `A_STATUS_CONFIRMED`, `A_STATUS_COMPLETED`, `A_STATUS_CANCELLED`, then a date chip showing the current date filter (`A_FILTER_DATE` or the chosen label); line `A_LAST_UPDATED` ("Cập nhật lúc {time}"); optional `BannerAction` for notifications (below); list of `OrderRow`; tab bar (owner only).
- Data shown per row: order code, customer name, status, delivery date and slot, cakes count, total, district (FR-8, AC-16). The row has no phone or address.
- Default filter: New and Confirmed selected, no date filter (FR-8). Order: delivery date, slot, placed time (BR-13, AC-15), the same for every filter. Status chips are multi-select; "Tất cả" selects all four; deselecting the last selected status is ignored and the chip row shakes once, so the filter never means nothing. A chip row change reloads from the first page. Search combines with filters (assumption A-D1); search starts after 3 typed characters or the search key, and `A_SEARCH_HINT` ("Mã đơn, tên khách hoặc số điện thoại. Chỉ đơn trong 90 ngày.") is the placeholder help line below the field when empty and focused.
- Paging: 50 rows at a time; reaching the last 5 rows loads the next 50; the footer shows a spinner, or on failure `A_LOAD_MORE_FAILED` with a retry text button (earlier rows stay) (BR-13, AC-23).
- Refresh: opening the screen, returning from background after more than 60 s, and pull-to-refresh reload from the first page and set the time in `A_LAST_UPDATED` (FR-12, AC-20, AC-21). The New count is the count of all New orders in the 90-day window, independent of the chips.
- Notification hint (FR-34, AC-51): when the system permission is denied, a `BannerAction` `A_NOTIF_HINT` with the button `A_OPEN_SETTINGS` shows once per sign-in; the close icon (label `A_DISMISS`) hides it until the next sign-in.
- Actions: open an order (FR-14); filter by status (FR-9); open date sheet (FR-10); search (FR-11); pull to refresh (FR-12); open account (staff).
- States:
  - Default: rows as above.
  - Loading: five `OrderRow` skeletons; the chips and search stay usable; on a refresh the old rows stay and the native refresh indicator shows.
  - Empty: `StateView` `A_ORDERS_EMPTY` ("Không có đơn nào phù hợp.") with the button `A_CLEAR_FILTERS` when a filter other than the default is set; with a search term the text is `A_SEARCH_EMPTY` (AC-19).
  - Error: `StateView` `A_ERR_GENERIC` and `A_RETRY`; rows already shown are replaced only on a full-list failure.
  - Offline: `StateView` `A_OFFLINE` and `A_RETRY`; no earlier rows are shown as current (AC-22). A short `Toast` is not enough.
  - Disabled: N/A (no disabled controls; the sign-in session ending leads to S-A1).
  - Success: N/A for the list (a status change is seen on S-A6 and in the row after return).
- Validation: search field accepts up to 100 characters; no other rules.

### S-A5 Date filter (sheet)

- Purpose: filter by delivery date (FR-10). Entry: date chip on S-A4. Exit: apply or close.
- Layout: sheet title `A_DATE_FILTER_TITLE`; single-select rows `A_DATE_ALL`, `A_DATE_TODAY`, `A_DATE_TOMORROW`, `A_DATE_ONE`, `A_DATE_RANGE`; for "one date" a native date picker below the row; for "range" two native pickers labelled `A_DATE_FROM` and `A_DATE_TO`; `PrimaryButton` `A_APPLY`; text button `A_RESET`.
- Data: "today" and "tomorrow" are computed on the server date in Vietnam time (AC-18). The chip on S-A4 then reads "Hôm nay", "Ngày mai", "dd/MM" or "dd/MM – dd/MM".
- Validation: range with end before start shows `A_ERR_RANGE`; Apply stays disabled.
- States: Default; Loading N/A (local); Empty N/A; Error N/A (no network); Disabled (Apply when the range is invalid); Success (sheet closes, list reloads).

### S-A6 Order detail

- Purpose: read one order and move it forward (FR-14 to FR-20). Entry: row tap; notification tap (FR-33, AC-50). Exit: back to S-A4 (the list reloads on return).
- Layout, top to bottom: `TopBar` (title is the code, `OrderCodeDisplay` style, selectable) with `StatusBadge`; customer `GlassCard` (section label `A_SEC_CUSTOMER`: name, phone, and two `ContactButton` capsules `A_CALL` ("Gọi {phone}") and `A_ZALO` ("Nhắn Zalo"), FR-15); delivery card (`A_SEC_DELIVERY`: weekday, date and slot; address, district); cakes card (`A_SEC_CAKES`: per cake name, quantity, unit price, line total as stored, then `SummaryRow` delivery fee and total, FR-14, AC-24); note card (`A_SEC_NOTE`, only if there is a note); cancel reason card (`A_SEC_REASON`, only if cancelled); history `HistoryTimeline` (`A_SEC_HISTORY`, FR-20, AC-31); placed date and time line `A_PLACED_AT`; `BottomActionBar` (below).
- Action bar by status: New: left `A_CANCEL_ORDER` (destructive), right `A_CONFIRM_ORDER`; Confirmed: left `A_CANCEL_ORDER`, right `A_COMPLETE_ORDER`; Completed and Cancelled: no bar (AC-27, AC-30). Confirm = one tap, no dialog (G-2). Complete = `ConfirmDialog` `A_COMPLETE_TITLE`/`A_COMPLETE_BODY` naming the code with `A_COMPLETE_YES` and `A_BACK` (design choice: final action, allowed before the delivery date, see Q-D2). Cancel opens S-A7.
- Behaviour: after Confirm or Complete the badge, bar and history update in place with `motion.spring.standard` and a success haptic; a `Toast` `A_STATUS_CHANGED` shows. During the request the pressed button shows a spinner and the other is disabled. Call opens the dialer with the number; Zalo opens the Zalo chat for the number, else `Toast` `A_ZALO_UNAVAILABLE` (AC-25; behaviour per ADR-0015). The phone is selectable text.
- Conflict (FR-19, AC-30): if the server refuses because the order changed, the screen reloads, shows the current status and an `InlineMessage` (Warning) `A_CONFLICT` with `{status}` at the top, error haptic; any open sheet or dialog closes.
- States:
  - Default: as above.
  - Loading: skeleton cards; bar hidden until the order is known.
  - Empty: N/A (an order always has data). Order not found or older than 90 days (including from a notification): `StateView` `A_ORDER_GONE` with `A_BACK_TO_LIST` (FR-41, AC-67).
  - Error: `StateView` `A_ERR_GENERIC`, `A_RETRY`. A failed status action shows `InlineMessage` (Error) `A_ERR_STATUS` above the bar; buttons return to enabled.
  - Offline: `StateView` `A_OFFLINE`, `A_RETRY`; on a status action `A_OFFLINE_SAVE` and the status stays unchanged.
  - Disabled: the other bar button while one request runs.
  - Success: status updated as above.

### S-A7 Cancel order (sheet)

- Purpose: cancel with one required reason (FR-18, BR-16). Entry: `A_CANCEL_ORDER` on S-A6. Exit: close (back) or done.
- Layout: sheet title `A_CANCEL_TITLE`; text `A_CANCEL_BODY` naming the order code `{code}` and saying the cakes go back to the delivery date (BR-3); `ReasonList` with exactly five reasons `A_REASON_CUSTOMER`, `A_REASON_FULL`, `A_REASON_CANNOT_DELIVER`, `A_REASON_NO_CONTACT`, `A_REASON_SPAM` (none preselected, AC-69); `PrimaryButton` with destructive fill `A_CANCEL_CONFIRM` ("Hủy đơn {code}"), disabled until a reason is chosen; `SecondaryButton` `A_BACK` (status unchanged, AC-29).
- Behaviour: success closes the sheet, S-A6 shows Cancelled with the reason card, `Toast` `A_STATUS_CHANGED`. The reason is not shown to the customer (note under the list `A_REASON_INTERNAL`: "Lý do chỉ nhân viên thấy.").
- States: Default (nothing selected, confirm disabled); Loading (spinner in confirm); Empty N/A (fixed list); Error (`InlineMessage` `A_ERR_STATUS`, sheet stays); Offline (`A_OFFLINE_SAVE`); Disabled (confirm until a reason); Success (close). Conflict: as S-A6.
