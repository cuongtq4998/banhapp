# Admin Orders UI, part 8: Content and copy, common, sign-in, orders (section 8)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.1 | 2026-10-31] Vietnamese text lives only in the copy parts (8 and 9). Placeholders: `{n}`, `{email}`, `{seconds}`, `{minutes}`, `{code}`, `{phone}`, `{status}`, `{name}`, `{date}`, `{time}`, `{datetime}`, `{total}`, `{district}`, `{field}`, `{min}`, `{max}`. Copy is final unless marked "pending"; a native speaker review is advised before release (Q-D3). Status names never use colour alone. Deleted in v1.1 (unused): `A_DISMISS`, `A_APPLY`, `A_NEW_COUNT`, `A_LAST_UPDATED`, `A_NOTIF_HINT`, `A_OPEN_SETTINGS`, `A_DATE_FILTER_TITLE`, `A_DATE_RANGE`, `A_DATE_FROM`, `A_DATE_TO`, `A_ERR_RANGE`, `A_SEC_HISTORY`, `A_HIST_CREATED`, `A_HIST_CHANGE`, `A_HIST_BY`, `A_HIST_REASON`, `A_REASON_FULL`, `A_LOST_PHONE`, `A_CODE_LOCKED` and the eight `A_RECOVERY_*`/`A_SEND_TWO_CODES`/`A_SIGNIN_RECOVERY` keys.

## 8.1 Common

| Key | Vietnamese |
| --- | ---------- |
| `A_RETRY` | Thử lại |
| `A_BACK` | Quay lại |
| `A_SAVE` | Lưu |
| `A_SAVED` | Đã lưu. |
| `A_RESET` | Đặt lại |
| `A_ERR_GENERIC` | Có lỗi xảy ra. Vui lòng thử lại. |
| `A_OFFLINE` | Không có kết nối mạng. Kiểm tra mạng rồi thử lại. |
| `A_OFFLINE_SAVE` | Không có kết nối mạng. Chưa lưu được. |
| `A_OFFLINE_SIGNOUT` | Không có mạng. Đã đăng xuất trên máy này. [v1.1 | 2026-10-31] |
| `A_ERR_FORBIDDEN` | Bạn không có quyền thực hiện việc này. |
| `A_SESSION_ENDED` | Phiên đăng nhập đã hết. Vui lòng đăng nhập lại. |
| `A_DISCARD_TITLE` | Bỏ thay đổi? |
| `A_DISCARD_BODY` | Các thay đổi chưa lưu sẽ mất. |
| `A_DISCARD` | Bỏ thay đổi |
| `A_KEEP_EDITING` | Tiếp tục sửa |
| `A_ERR_REQUIRED` | {field}: vui lòng nhập. |
| `A_ERR_TOO_LONG` | {field}: tối đa {max} ký tự. |
| `A_ERR_RANGE_INT` | {field}: nhập số nguyên từ {min} đến {max}. |
| `A_ERR_PHONE` | {field}: số điện thoại không hợp lệ. |
| `A_ACTIVE` | Đang dùng |
| `A_STATUS_NEW` | Mới |
| `A_STATUS_CONFIRMED` | Đã xác nhận |
| `A_STATUS_COMPLETED` | Đã hoàn thành |
| `A_STATUS_CANCELLED` | Đã hủy |
| `A_SIGN_OUT` | Đăng xuất |
| `A_SIGNOUT_TITLE` | Đăng xuất? |
| `A_SIGNOUT_BODY` | Thông tin khách hàng sẽ được xóa khỏi máy này. |
| `A_SIGNOUT_OTHERS` | Đăng xuất các máy khác [v1.1 | 2026-10-31] |
| `A_SIGNOUT_OTHERS_TITLE` | Đăng xuất các máy khác? [v1.1 | 2026-10-31] |
| `A_SIGNOUT_OTHERS_BODY` | Mọi máy khác đang đăng nhập tài khoản này sẽ bị đăng xuất trong tối đa 5 phút. Máy này vẫn dùng bình thường. [v1.1 | 2026-10-31] |
| `A_SIGNOUT_OTHERS_DONE` | Đã đăng xuất các máy khác. [v1.1 | 2026-10-31] |

## 8.2 Sign-in (S-A1, S-A2)

| Key | Vietnamese |
| --- | ---------- |
| `A_SIGNIN_TITLE` | Quản lý đơn hàng |
| `A_SIGNIN_HINT` | Nhập email để nhận mã xác thực 6 số. Chỉ email do Chủ tiệm thêm mới đăng nhập được. |
| `A_EMAIL_LABEL` | Email |
| `A_SEND_CODE` | Gửi mã |
| `A_SESSION_NOTE` | Máy này được nhớ 7 ngày, và gia hạn mỗi lần bạn dùng. |
| `A_ERR_EMAIL_INVALID` | Email không hợp lệ. |
| `A_ERR_RATE_SEND` | Bạn đã yêu cầu mã quá nhiều lần. Thử lại sau {minutes} phút. |
| `A_CODE_TITLE` | Nhập mã xác thực |
| `A_CODE_PROMPT` | Nhập mã 6 số đã gửi về {email} |
| `A_CODE_FIELD_A11Y` | Mã xác thực 6 số |
| `A_RESEND_WAIT` | Gửi lại sau {seconds} giây |
| `A_RESEND` | Gửi lại mã |
| `A_CHANGE_EMAIL` | Đổi email |
| `A_SIGNIN` | Đăng nhập |
| `A_CODE_WRONG` | Mã không đúng. Kiểm tra lại mã trong email. |
| `A_CODE_EXPIRED` | Mã không còn hiệu lực. Hãy yêu cầu mã mới. [v1.1 | 2026-10-31] |

## 8.3 Orders (S-A3 to S-A5)

| Key | Vietnamese |
| --- | ---------- |
| `A_ORDERS_TITLE` | Đơn hàng |
| `A_TAB_BADGE_A11Y` | {n} đơn cần xử lý [v1.1 | 2026-10-31] |
| `A_ACCOUNT_A11Y` | Tài khoản |
| `A_SEARCH_PLACEHOLDER` | Tìm mã đơn, tên, số điện thoại |
| `A_SEARCH_HINT` | Mã đơn, tên khách hoặc số điện thoại. Chỉ tìm trong đơn 90 ngày gần đây. |
| `A_SEARCH_MIN` | Nhập ít nhất 3 ký tự để tìm. [v1.1 | 2026-10-31] |
| `A_FILTER_TODO` | Cần làm [v1.1 | 2026-10-31] |
| `A_FILTER_ALL` | Tất cả |
| `A_FILTER_DATE` | Ngày giao |
| `A_DATE_ALL` | Mọi ngày |
| `A_DATE_TODAY` | Hôm nay |
| `A_DATE_TOMORROW` | Ngày mai |
| `A_DATE_ONE` | Chọn một ngày… |
| `A_DUE_TODAY` | Giao hôm nay [v1.1 | 2026-10-31] |
| `A_OVERDUE` | Quá hạn {n} ngày [v1.1 | 2026-10-31] |
| `A_ROW_HINT_A11Y` | Mở chi tiết đơn |
| `A_ROW_DELIVERY` | {date} · {slot} |
| `A_ROW_META` | {n} bánh · {total} · {district} |
| `A_LOAD_MORE_FAILED` | Không tải thêm được. |
| `A_ORDERS_EMPTY` | Không có đơn nào phù hợp. |
| `A_TODO_EMPTY` | Không còn đơn nào cần làm. [v1.1 | 2026-10-31] |
| `A_SEARCH_EMPTY` | Không tìm thấy đơn nào. |
| `A_CLEAR_FILTERS` | Xóa bộ lọc |
| `A_SEC_CUSTOMER` | Khách hàng |
| `A_SEC_DELIVERY` | Giao hàng |
| `A_SEC_CAKES` | Bánh đã đặt |
| `A_SEC_NOTE` | Ghi chú của khách |
| `A_SEC_REASON` | Lý do hủy |
| `A_PLACED_AT` | Đặt lúc {datetime} |
| `A_LAST_CHANGED` | Cập nhật lần cuối bởi {name}, {datetime} [v1.1 | 2026-10-31] |
| `A_HIST_CUSTOMER` | khách hàng |
| `A_FEE` | Phí giao hàng |
| `A_TOTAL` | Tổng cộng |
| `A_CALL` | Gọi {phone} |
| `A_ZALO` | Nhắn Zalo |
| `A_ZALO_UNAVAILABLE` | Không mở được Zalo trên máy này. |
| `A_CONFIRM_ORDER` | Xác nhận đơn |
| `A_COMPLETE_ORDER` | Hoàn thành |
| `A_CANCEL_ORDER` | Hủy đơn |
| `A_COMPLETE_TITLE` | Hoàn thành đơn {code}? |
| `A_COMPLETE_BODY` | Đơn đã hoàn thành thì không mở lại được. |
| `A_COMPLETE_YES` | Hoàn thành |
| `A_STATUS_CHANGED` | Đã cập nhật trạng thái đơn. |
| `A_CONFLICT` | Đơn này vừa được người khác thay đổi. Trạng thái hiện tại: {status}. |
| `A_ORDER_GONE` | Không tìm thấy đơn, hoặc đơn đã quá 90 ngày. |
| `A_BACK_TO_LIST` | Về danh sách |
| `A_ERR_STATUS` | Không đổi được trạng thái đơn. Vui lòng thử lại. |
| `A_CANCEL_TITLE` | Hủy đơn |
| `A_CANCEL_BODY` | Hủy đơn {code}? Số bánh sẽ được trả lại cho ngày giao. Hãy chọn một lý do. |
| `A_REASON_CUSTOMER` | Khách yêu cầu hủy |
| `A_REASON_CANNOT_DELIVER` | Không giao được (kể cả khi ngày đã đầy) [v1.1 | 2026-10-31] |
| `A_REASON_NO_CONTACT` | Không liên lạc được với khách |
| `A_REASON_SPAM` | Đơn giả hoặc spam |
| `A_CANCEL_CONFIRM` | Hủy đơn {code} |
| `A_REASON_INTERNAL` | Lý do chỉ nhân viên và Chủ tiệm thấy, khách không thấy. |
