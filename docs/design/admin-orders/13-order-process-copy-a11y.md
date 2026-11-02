# Admin Orders UI, part 13: Order process, copy, accessibility, test ids (sections 8.8, 9.3)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). Screens: [part 12](12-order-process-screens.md). New in v1.4. English source text is not kept in the app: the app has one locale, Vietnamese (copy keys in code resources, as in parts 8 and 9); the English column is the meaning for reviewers. Placeholders `{x}` are filled by the app. [v1.4 | 2026-11-02]

## 8.8 Copy keys added or changed

| Key | Vietnamese | Meaning (English) |
| --- | ---------- | ----------------- |
| `A_STATUS_RECEIVED` | Đã nhận đơn | Received (replaces `A_STATUS_NEW`) |
| `A_STATUS_PROCESSING` | Đang xử lý | Processing (replaces `A_STATUS_CONFIRMED`) |
| `A_STATUS_SCHEDULED` | Đã hẹn ngày giao | Delivery date scheduled |
| `A_STATUS_DELIVERING` | Đang giao | Delivery started |
| `A_STATUS_FINISHED` | Đã hoàn thành | Finished (replaces `A_STATUS_COMPLETED`) |
| `A_PROCESS_ORDER` | Bắt đầu xử lý | Start processing (replaces `A_CONFIRM_ORDER`) |
| `A_SCHEDULE_DATE` | Hẹn ngày giao | Schedule delivery date |
| `A_CHANGE_DATE` | Đổi ngày giao | Change delivery date |
| `A_START_DELIVERY` | Bắt đầu giao | Start delivery |
| `A_FINISH_ORDER` | Kết thúc | Finish (replaces `A_COMPLETE_ORDER`) |
| `A_FINISH_TITLE` | Kết thúc đơn {code}? | Finish confirmation title (replaces `A_COMPLETE_TITLE`) |
| `A_FINISH_BODY` | Đơn đã kết thúc thì không mở lại được. | Finished cannot be reopened (replaces `A_COMPLETE_BODY`) |
| `A_FINISH_YES` | Kết thúc | Confirm button (replaces `A_COMPLETE_YES`) |
| `A_CANCEL_BLOCKED` | Không thể hủy đơn từ bước đã hẹn ngày giao vì bánh có thể không có người nhận. | Why cancel is gone |
| `A_REQUESTED_DATE` | Khách chọn | Customer's requested date |
| `A_EXPECTED_DATE` | Dự kiến giao | Expected delivery date |
| `A_ROW_EXPECTED` | Dự kiến {date} | List row date when expected |
| `A_CAKES_TOTAL` | Tiền bánh | Cakes total |
| `A_FEE_PENDING` | Báo khi giao | Fee told at delivery |
| `A_FEE_FREE` | Miễn phí giao hàng | Free delivery (fee 0) |
| `A_FEE_ESTIMATE_LINE` | Phí dự kiến theo quận: {amount} | District estimate |
| `A_TOTAL_COLLECT` | Cần thu khi giao | Amount to collect |
| `A_STEP_CURRENT` | Hiện tại | Current step |
| `A_STEP_A11Y` | Bước {n} trên 5: {name}, {state} | State is done, current or next (keys `A_STEP_DONE`: đã xong, `A_STEP_NEXT`: sắp tới, `A_STEP_CURRENT`) |
| `A_SCHEDULE_TITLE` | Hẹn ngày giao đơn {code} | S-A14 title |
| `A_RESCHEDULE_TITLE` | Đổi ngày giao đơn {code} | S-A14 title in change mode |
| `A_SCHEDULE_HELP` | Ngày này chỉ là dự kiến, có thể đổi lại. | Help line |
| `A_SCHEDULE_SAVE` | Hẹn ngày giao | Save, schedule |
| `A_RESCHEDULE_SAVE` | Lưu ngày mới | Save, change |
| `A_DATE_SAVED` | Đã lưu ngày giao dự kiến. | Toast |
| `A_FEE_TITLE` | Bắt đầu giao đơn {code} | S-A15 title |
| `A_FEE_BODY` | Nhập phí giao hàng thực tế. Nhập 0 nếu miễn phí. | Fee help |
| `A_F_REAL_FEE` | Phí giao hàng thực tế (đồng) | Field label |
| `A_START_DELIVERY_CONFIRM` | Bắt đầu giao đơn {code} | Confirm button |
| `A_ERR_FEE_REQUIRED` | Vui lòng nhập phí giao hàng (nhập 0 nếu miễn phí). | Empty fee |
| `A_ERR_FEE_RANGE` | Phí giao hàng là số nguyên từ 0 đến 10.000.000 đồng. | Out of range |
| `A_F_FEE_ESTIMATE` | Phí dự kiến (đồng) | S-A10 label (replaces `A_F_FEE`) |
| `A_FEE_EFFECT_ESTIMATE` | Khách chỉ thấy đây là phí dự kiến. Phí thật nhập khi bắt đầu giao. | S-A10 note (replaces `A_FEE_EFFECT`) |
| `A_FEE_ESTIMATE_TAG` | dự kiến | S-A10 row tag |

Existing keys `A_FEE`, `A_TOTAL`, `A_CONFLICT`, `A_ERR_STATUS`, `A_OFFLINE_SAVE`, `A_BACK`, `A_STATUS_CHANGED`, `A_STATUS_CANCELLED`, `A_DUE_TODAY`, `A_OVERDUE` stay. `A_TOTAL` is used only where the PRD still allows a total: not before the fee is entered (superseded by `A_TOTAL_COLLECT`). Deleted keys: `A_STATUS_NEW`, `A_STATUS_CONFIRMED`, `A_STATUS_COMPLETED`, `A_CONFIRM_ORDER`, `A_COMPLETE_ORDER`, `A_COMPLETE_TITLE`, `A_COMPLETE_BODY`, `A_COMPLETE_YES`, `A_F_FEE`, `A_FEE_EFFECT`. Vietnamese wording is a draft for the native review in Q-D3.

## 9.3 Accessibility

- Stepper: one element with the label from `A_STEP_A11Y` per row, in order; the current row is read with `A_STEP_CURRENT`. Status is also in the badge text, never colour only.
- The `A_CANCEL_BLOCKED` message is plain text read before the bar; it is not a disabled control, so a screen reader user meets no unexplained missing button.
- Sheets: focus goes to the title, then the picker (S-A14) or the fee field (S-A15, with the keyboard open). The fee total updates are announced politely (`liveRegion polite` on Android, `accessibilityValue` update on iOS). Errors are announced as alerts and linked to the field.
- Date picker uses the platform picker with its own screen-reader support; the chosen date is also written as text `dd/MM/yyyy` with weekday above the picker.
- Touch targets 48 x 48 dp at least; the expected date tap target is the whole line. Dynamic type to 200 percent: sheets scroll, the bar stays pinned; stepper rows wrap to two lines.
- Reduce motion: no spring on the stepper marker; fade only. Haptics unchanged (success on step change, error on conflict).

## 9.4 Test identifiers added (platform deviations are listed per part 10, 9.2)

`admin.order.stepper` and `admin.order.step.<1..5>`; `admin.order.expectedDate`; `admin.order.requestedDate`; `admin.order.fee` (value or pending text); `admin.order.feeEstimate`; `admin.order.totalCollect`; `admin.order.cancelBlocked`; actions `admin.order.process`, `admin.order.schedule`, `admin.order.changeDate`, `admin.order.startDelivery`, `admin.order.finish` (replace `confirm` and `complete`); sheet S-A14 `admin.schedule.sheet`, `.picker`, `.save`, `.back`; sheet S-A15 `admin.fee.sheet`, `.field`, `.error`, `.total`, `.confirm`, `.back`; list chips `admin.orders.filter.<received|processing|scheduled|delivering|finished|cancelled|todo|all>`; row `admin.orders.row.expected`. [v1.4 | 2026-11-02]
