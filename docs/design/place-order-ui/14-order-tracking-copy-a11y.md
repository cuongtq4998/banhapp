# Place Order UI, part 14: Order tracking, copy, accessibility, test ids

Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Screens: [part 13](13-order-tracking.md). Version 1.0 [v1.0 | 2026-11-02]. Owner approved 2026-11-02; based on `product/place-order.md` v1.10. One locale (Vietnamese, copy keys in code resources); the English column is the meaning for reviewers; the wording is a draft for the native review.

## Copy keys

| Key | Vietnamese | Meaning |
| --- | ---------- | ------- |
| `T_TRACK_ENTRY` | Theo dõi đơn | Entry row on the home screen S-2 (not in a menu) [v1.0 | 2026-11-02] |
| `T_TRACK_TITLE` | Theo dõi đơn hàng | Screen title |
| `T_TRACK_HELP` | Nhập số điện thoại bạn đã dùng để đặt bánh. | Help |
| `T_F_PHONE` | Số điện thoại | Field label |
| `T_TRACK_SUBMIT` | Xem đơn | Submit |
| `T_TRACK_PRIVACY` | Chỉ hiển thị số điện thoại đã ẩn và quận. | Privacy line |
| `T_ERR_PHONE` | Số điện thoại chưa đúng. Vui lòng kiểm tra lại. | Invalid phone |
| `T_FOLLOW_ORDER` | Theo dõi đơn này | Confirmation shortcut |
| `T_RESULT_FOR` | Đơn của {phone} | Summary line (masked phone) |
| `T_AS_OF` | Cập nhật lúc {time} | Updated at |
| `T_STALE_AS_OF` | Dữ liệu lúc {time}. Không có mạng. | Offline stale |
| `T_LOAD_MORE` | Đang tải thêm | Page loading |
| `T_LIST_END_LIMIT` | Đang hiển thị 50 đơn mới nhất. Liên hệ cửa hàng nếu cần xem đơn cũ hơn. | Paging limit |
| `T_ORDER_CODE` | Mã đơn {code} | Order code |
| `T_STEP_RECEIVED` | Đã nhận đơn | Step 1 |
| `T_STEP_PROCESSING` | Đang xử lý | Step 2 |
| `T_STEP_SCHEDULED` | Đã hẹn ngày giao | Step 3 |
| `T_STEP_DELIVERING` | Đang giao | Step 4 |
| `T_STEP_FINISHED` | Đã hoàn thành | Step 5 |
| `T_REQUESTED` | Bạn chọn: {date}, {slot} | Requested date |
| `T_EXPECTED` | Dự kiến giao: {date} | Expected date |
| `T_EXPECTED_MAY_MOVE` | Ngày này có thể thay đổi. Cần hỏi thêm, vui lòng gọi cửa hàng. | [v1.0 | 2026-11-02] The date may change; call the shop for questions; no promise of a notification (there is no push) |
| `T_CAKE_LINE` | {name} x {quantity} | [v1.0 | 2026-11-02] Cake name and quantity line |
| `T_OLDER_MAY_HIDDEN` | Đơn cũ hơn có thể không còn hiển thị. Vui lòng liên hệ cửa hàng nếu cần. | [v1.0 | 2026-11-02] Neutral line, no number of days |
| `T_CAKES_TOTAL` | Tiền bánh | Cakes total |
| `T_FEE_ESTIMATE_LINE` | Phí giao dự kiến: {amount} | Estimate until real fee |
| `T_FEE_FINAL` | Phí giao hàng | Real fee |
| `T_FEE_FREE` | Miễn phí giao hàng | Fee 0 |
| `T_TOTAL_COLLECT` | Cần thanh toán khi nhận | Amount to collect |
| `T_STATUS_CANCELLED` | Đã hủy | Cancelled |
| `T_CANCELLED_CONTACT` | Vui lòng liên hệ cửa hàng nếu cần hỗ trợ. | Cancelled, no reason |
| `T_CALL_SHOP` | Gọi cửa hàng | Call |
| `T_ZALO_SHOP` | Nhắn Zalo | Zalo |
| `T_EMPTY_TITLE` | Không có đơn nào gần đây | Empty |
| `T_EMPTY_BODY` | Chúng tôi không thấy đơn nào cho số này. Bạn có thể đặt bánh hoặc liên hệ cửa hàng. | Empty (same for every number) |
| `T_ORDER_NOW` | Đặt bánh | Go to order |
| `T_ERR_RATE` | Bạn thử quá nhiều lần. Vui lòng thử lại sau {wait}. | 429 |
| `T_ERR_GENERIC` | Không tải được đơn. Vui lòng thử lại. | Error |
| `T_OFFLINE` | Không có kết nối mạng. | Offline |
| `T_RETRY` | Thử lại | Retry |

## Accessibility

- Order card is one grouped element read as: code, cake names with quantities [v1.0 | 2026-11-02], step name and state, expected date with the note, fee or estimate, amount to collect. Stepper rows use the same pattern as the admin `A_STEP_A11Y` (step n of 5, name, done, current, next); status never by colour only.
- Empty and rate-limit messages are announced politely; the countdown announces only at start and when it ends, not every second. Pull to refresh has an accessible "refresh" action on the list.
- Phone field: label, numeric keyboard hint, error linked to the field; masked phone is read digit by digit with "ẩn" for the stars (`T_RESULT_FOR` a11y value built from the digits).
- Call and Zalo are buttons of at least 48 x 48 dp. Dynamic type to 200 percent: cards wrap, stepper rows wrap to two lines, nothing truncated. Reduce motion: fade only.

## Test identifiers (customer prefix `order.track.`; deviations per part 09b)

`order.track.entry`; `order.track.phone`, `.submit`, `.error`; `order.track.list`, `.row.<n>`, `.row.<n>.code`, `.row.<n>.cakes` [v1.0 | 2026-11-02], `.row.<n>.stepper`, `.row.<n>.expected`, `.row.<n>.fee`, `.row.<n>.total`; `.empty`, `.rateLimit`, `.offline`, `.loadMore`, `.retry`, `.cancelledContact`; `order.confirm.follow` on S-9.

## Traceability [v1.0 | 2026-11-02]

| Element | Requirement |
| ------- | ----------- |
| S-10 phone entry, no sign-in | FR-22, BR-16 |
| S-11 list, paging 10 x 5, newest first | FR-23, AC-38 to AC-41 |
| Home entry row, S-9 shortcut with phone in memory | FR-22 |
| Cake names and quantities on the card, neutral older-order line | FR-23, FR-27 |
| Five steps, expected date note, estimate then real fee | FR-24, FR-28 to FR-30, BR-15 |
| Cancelled without reason, shop contact | FR-25, BR-17 |
| Empty answer identical for any number, 429 | FR-26, BR-18 |
| Masked phone, district only | AC-47 |
