# Admin Orders UI, part 8: Content and copy, common, sign-in, orders (section 8)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31] Vietnamese text lives only in the copy parts (8 and 9). Placeholders: `{n}`, `{email}`, `{seconds}`, `{minutes}`, `{code}`, `{phone}`, `{status}`, `{name}`, `{date}`, `{time}`, `{datetime}`, `{total}`, `{district}`, `{field}`, `{min}`, `{max}`. Copy is final unless marked "pending"; a native speaker review is advised before release (Q-D3). Status names never use colour alone.

## 8.1 Common

| Key | Vietnamese |
| --- | ---------- |
| `A_RETRY` | Thử lại |
| `A_BACK` | Quay lại |
| `A_SAVE` | Lưu |
| `A_SAVED` | Đã lưu. |
| `A_DISMISS` | Đóng |
| `A_APPLY` | Áp dụng |
| `A_RESET` | Đặt lại |
| `A_ERR_GENERIC` | Có lỗi xảy ra. Vui lòng thử lại. |
| `A_OFFLINE` | Không có kết nối mạng. Kiểm tra mạng rồi thử lại. |
| `A_OFFLINE_SAVE` | Không có kết nối mạng. Chưa lưu được. |
| `A_OFFLINE_SIGNOUT` | Không có mạng. Đã đăng xuất trên máy này. Nếu cần, hãy thu hồi máy này trong danh sách thiết bị. |
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

## 8.2 Sign-in and recovery (S-A1 to S-A3)

| Key | Vietnamese |
| --- | ---------- |
| `A_SIGNIN_TITLE` | Quản lý đơn hàng |
| `A_SIGNIN_HINT` | Nhập email để nhận mã xác thực 6 số. Chỉ email do Chủ tiệm thêm mới đăng nhập được. |
| `A_EMAIL_LABEL` | Email |
| `A_SEND_CODE` | Gửi mã |
| `A_LOST_PHONE` | Mất điện thoại? Đăng nhập khôi phục (Chủ tiệm) |
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
| `A_CODE_EXPIRED` | Mã đã hết hạn. Hãy gửi lại mã mới. |
| `A_CODE_LOCKED` | Bạn nhập sai quá nhiều lần. Thử lại sau {minutes} phút. |
| `A_RECOVERY_TITLE` | Đăng nhập khôi phục |
| `A_RECOVERY_INTRO` | Dành cho Chủ tiệm khi đổi điện thoại. Hai mã sẽ được gửi: một về email của bạn, một về email dự phòng. Chỉ dùng được khi đã đăng ký email dự phòng. |
| `A_SEND_TWO_CODES` | Gửi hai mã |
| `A_RECOVERY_CODE_OWNER` | Mã gửi về email Chủ tiệm |
| `A_RECOVERY_CODE_BACKUP` | Mã gửi về email dự phòng |
| `A_SIGNIN_RECOVERY` | Đăng nhập khôi phục |
| `A_RECOVERY_FAILED` | Không đăng nhập được. Kiểm tra cả hai mã hoặc gửi lại mã. |
| `A_RECOVERY_DONE` | Bạn vừa đăng nhập khôi phục. Đã gửi thông báo về cả hai email. Nếu điện thoại cũ bị mất, hãy thu hồi máy đó. |

## 8.3 Orders (S-A4 to S-A7)

| Key | Vietnamese |
| --- | ---------- |
| `A_ORDERS_TITLE` | Đơn hàng |
| `A_NEW_COUNT` | Mới: {n} |
| `A_ACCOUNT_A11Y` | Tài khoản |
| `A_SEARCH_PLACEHOLDER` | Tìm mã đơn, tên, số điện thoại |
| `A_SEARCH_HINT` | Mã đơn, tên khách hoặc số điện thoại. Chỉ tìm trong đơn 90 ngày gần đây. |
| `A_FILTER_ALL` | Tất cả |
| `A_FILTER_DATE` | Ngày giao |
| `A_LAST_UPDATED` | Cập nhật lúc {time} |
| `A_ROW_HINT_A11Y` | Mở chi tiết đơn |
| `A_ROW_DELIVERY` | {date} · {slot} |
| `A_ROW_META` | {n} bánh · {total} · {district} |
| `A_LOAD_MORE_FAILED` | Không tải thêm được. |
| `A_NOTIF_HINT` | Bạn chưa bật thông báo. Hãy bật trong Cài đặt của máy để nhận đơn mới ngay. |
| `A_OPEN_SETTINGS` | Mở Cài đặt |
| `A_ORDERS_EMPTY` | Không có đơn nào phù hợp. |
| `A_SEARCH_EMPTY` | Không tìm thấy đơn nào. |
| `A_CLEAR_FILTERS` | Xóa bộ lọc |
| `A_DATE_FILTER_TITLE` | Lọc theo ngày giao |
| `A_DATE_ALL` | Mọi ngày |
| `A_DATE_TODAY` | Hôm nay |
| `A_DATE_TOMORROW` | Ngày mai |
| `A_DATE_ONE` | Chọn một ngày |
| `A_DATE_RANGE` | Chọn khoảng ngày |
| `A_DATE_FROM` | Từ ngày |
| `A_DATE_TO` | Đến ngày |
| `A_ERR_RANGE` | Ngày kết thúc phải sau hoặc bằng ngày bắt đầu. |
| `A_SEC_CUSTOMER` | Khách hàng |
| `A_SEC_DELIVERY` | Giao hàng |
| `A_SEC_CAKES` | Bánh đã đặt |
| `A_SEC_NOTE` | Ghi chú của khách |
| `A_SEC_REASON` | Lý do hủy |
| `A_SEC_HISTORY` | Lịch sử |
| `A_PLACED_AT` | Đặt lúc {datetime} |
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
| `A_HIST_CREATED` | Khách đặt đơn |
| `A_HIST_CHANGE` | {old} → {new} |
| `A_HIST_BY` | bởi {name} |
| `A_HIST_CUSTOMER` | khách hàng |
| `A_HIST_REASON` | Lý do: {reason} |
| `A_CANCEL_TITLE` | Hủy đơn |
| `A_CANCEL_BODY` | Hủy đơn {code}? Số bánh sẽ được trả lại cho ngày giao. Hãy chọn một lý do. |
| `A_REASON_CUSTOMER` | Khách yêu cầu hủy |
| `A_REASON_FULL` | Hết chỗ trong ngày |
| `A_REASON_CANNOT_DELIVER` | Không giao được |
| `A_REASON_NO_CONTACT` | Không liên lạc được với khách |
| `A_REASON_SPAM` | Đơn giả hoặc spam |
| `A_CANCEL_CONFIRM` | Hủy đơn {code} |
| `A_REASON_INTERNAL` | Lý do chỉ nhân viên và Chủ tiệm thấy, khách không thấy. |
