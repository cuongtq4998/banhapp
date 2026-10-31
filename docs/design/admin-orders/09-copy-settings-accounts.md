# Admin Orders UI, part 9: Content and copy, settings, cakes, accounts, notifications (section 8)

Part of the split UI specification; index: [admin-orders-ui.md](../admin-orders-ui.md). [v1.0 | 2026-10-31] Same placeholders and rules as [part 8](08-copy-common-orders.md).

## 8.4 Settings (S-A8 to S-A12)

| Key | Vietnamese |
| --- | ---------- |
| `A_SETTINGS_TITLE` | Cài đặt |
| `A_BACKUP_REMINDER` | Bạn chưa đăng ký email dự phòng. Nếu mất điện thoại, bạn sẽ không khôi phục được tài khoản Chủ tiệm. |
| `A_SET_NOW` | Đăng ký ngay |
| `A_ROW_SHOP` | Thông tin cửa hàng |
| `A_ROW_RULES` | Quy tắc đặt hàng |
| `A_ROW_RULES_VALUE` | Giới hạn {limit} bánh/ngày |
| `A_ROW_SLOTS` | Khung giờ giao |
| `A_ROW_DISTRICTS` | Quận/huyện và phí giao |
| `A_ROW_CAKES` | Bánh |
| `A_ROW_STAFF` | Nhân viên |
| `A_ROW_DEVICES` | Thiết bị đăng nhập |
| `A_ROW_BACKUP` | Email dự phòng |
| `A_NEW_ORDERS_ONLY` | Thay đổi chỉ áp dụng cho đơn đặt sau khi lưu. Đơn đã đặt giữ nguyên. |
| `A_F_SHOP_NAME` | Tên cửa hàng |
| `A_F_GREETING` | Lời chào |
| `A_F_PHONE` | Số điện thoại liên hệ |
| `A_F_ZALO` | Số Zalo |
| `A_F_LIMIT` | Số bánh tối đa mỗi ngày |
| `A_F_LEAD` | Đặt trước tối thiểu (ngày) |
| `A_F_MIN` | Số bánh tối thiểu mỗi đơn |
| `A_HORIZON_FIXED` | Khách đặt trước tối đa 30 ngày. Mục này không thay đổi được. |
| `A_RULES_EFFECT` | Khách sẽ thấy các giá trị mới ở những nơi có nêu quy tắc. |
| `A_ERR_MIN_ABOVE_LIMIT` | {field}: không được lớn hơn số bánh tối đa mỗi ngày. |
| `A_LIMIT_WARN_TITLE` | Một số ngày đã vượt giới hạn mới |
| `A_LIMIT_WARN_BODY` | Có {count} ngày đã nhận nhiều bánh hơn giới hạn mới. Đơn đã đặt vẫn giữ nguyên và không bị hủy; những ngày này sẽ hiện là đã đầy. |
| `A_SAVE_ANYWAY` | Vẫn lưu |
| `A_ADD_SLOT` | Thêm khung giờ |
| `A_SLOT_ADD_TITLE` | Thêm khung giờ |
| `A_SLOT_EDIT_TITLE` | Sửa khung giờ |
| `A_F_START` | Giờ bắt đầu |
| `A_F_END` | Giờ kết thúc |
| `A_ERR_SLOT_ORDER` | Giờ bắt đầu phải trước giờ kết thúc. |
| `A_ERR_SLOT_DUP` | Khung giờ này đã có. |
| `A_ERR_LAST_SLOT` | Phải còn ít nhất một khung giờ đang dùng. |
| `A_SLOTS_EMPTY` | Chưa có khung giờ nào. |
| `A_ADD_DISTRICT` | Thêm quận/huyện |
| `A_F_DISTRICT` | Tên quận/huyện |
| `A_F_FEE` | Phí giao hàng (đồng) |
| `A_FEE_EFFECT` | Phí mới chỉ áp dụng cho đơn đặt sau khi lưu. |
| `A_ERR_DISTRICT_DUP` | Quận/huyện này đã có. |
| `A_ERR_LAST_DISTRICT` | Phải còn ít nhất một quận/huyện đang dùng. |
| `A_DISTRICTS_EMPTY` | Chưa có quận/huyện nào. |

## 8.5 Cakes (S-A13 to S-A15)

| Key | Vietnamese |
| --- | ---------- |
| `A_CAKES_COUNT` | {n}/12 bánh |
| `A_ADD_CAKE` | Thêm bánh |
| `A_ADD_CAKE_TITLE` | Thêm bánh mới |
| `A_ADD_CAKE_SAVE` | Thêm bánh |
| `A_CAKES_FULL` | Đã đủ 12 bánh. Hãy xóa một bánh trước khi thêm bánh mới. |
| `A_ERR_CAKES_FULL` | Không thêm được: đã có 12 bánh. |
| `A_CAKES_EMPTY` | Chưa có bánh nào. |
| `A_CAKE_ACTIVE` | Đang bán |
| `A_CAKE_HIDDEN` | Đã ẩn |
| `A_CAKE_ACTIVE_TOGGLE` | Đang bán |
| `A_CAKE_HIDDEN_HELP` | Bánh đã ẩn không hiện cho khách và không đặt được. Bạn có thể bật lại. |
| `A_F_CAKE_NAME` | Tên bánh |
| `A_F_CAKE_DESC` | Mô tả |
| `A_F_PRICE` | Giá (đồng) |
| `A_IMG_NOT_EDITABLE` | Ảnh không đổi được. Muốn đổi ảnh, hãy thêm bánh mới rồi xóa bánh này. |
| `A_IMG_PICK` | Chọn ảnh bánh |
| `A_IMG_CHANGE` | Đổi ảnh |
| `A_IMG_REMOVE_PICK` | Bỏ ảnh đã chọn |
| `A_IMG_FAILED_A11Y` | Ảnh bánh không tải được |
| `A_ERR_IMG_REQUIRED` | Ảnh bánh: vui lòng chọn ảnh. |
| `A_ERR_IMG_TYPE` | Ảnh bánh: chỉ nhận ảnh JPEG hoặc PNG. |
| `A_ERR_IMG_SIZE` | Ảnh bánh: tối đa 5 MB. |
| `A_ERR_IMG_READ` | Không đọc được ảnh. Hãy chọn ảnh khác. |
| `A_ERR_UPLOAD` | Không tải được ảnh lên. Bánh chưa được thêm. Vui lòng thử lại. |
| `A_UPLOADING` | Đang tải ảnh… {percent}% |
| `A_CANCEL_UPLOAD` | Dừng tải lên |
| `A_NEW_CAKE_ACTIVE` | Bánh mới sẽ hiện ngay cho khách. |
| `A_CAKE_ADDED` | Đã thêm bánh. |
| `A_ERR_CAKE_NAME_DUP` | Tên bánh: đã có bánh khác dùng tên này. |
| `A_ERR_LAST_CAKE` | Phải còn ít nhất một bánh đang bán. |
| `A_REMOVE_CAKE` | Xóa bánh |
| `A_REMOVE_TITLE` | Xóa bánh {name}? |
| `A_REMOVE_BODY` | Bánh sẽ biến mất khỏi ứng dụng của khách và không khôi phục được. Đơn đã đặt vẫn giữ tên và giá bánh. |
| `A_REMOVE_YES` | Xóa bánh |
| `A_CAKE_REMOVED` | Đã xóa bánh. |
| `A_CAKE_GONE` | Bánh này không còn nữa. |

## 8.6 Staff, devices, backup e-mail (S-A16 to S-A20)

| Key | Vietnamese |
| --- | ---------- |
| `A_STAFF_COUNT` | {n}/30 nhân viên đang hoạt động |
| `A_ADD_STAFF` | Thêm nhân viên |
| `A_ADD_STAFF_SAVE` | Thêm nhân viên |
| `A_STAFF_FULL` | Đã đủ 30 nhân viên đang hoạt động. Hãy tắt một tài khoản trước khi thêm. |
| `A_ERR_STAFF_FULL` | Không thêm hoặc bật lại được: đã đủ 30 nhân viên đang hoạt động. |
| `A_STAFF_NONE` | Chưa có nhân viên nào. |
| `A_ROLE_OWNER` | Chủ tiệm |
| `A_ROLE_STAFF` | Nhân viên |
| `A_ACCT_ACTIVE` | Đang hoạt động |
| `A_ACCT_OFF` | Đã tắt |
| `A_DEACTIVATE` | Tắt tài khoản |
| `A_DEACTIVATE_TITLE` | Tắt tài khoản của {name}? |
| `A_DEACTIVATE_BODY` | {name} sẽ bị đăng xuất trên mọi máy và không nhận thông báo nữa. Lịch sử đơn vẫn giữ tên. |
| `A_REACTIVATE` | Bật lại tài khoản |
| `A_F_STAFF_NAME` | Tên nhân viên |
| `A_STAFF_ADD_HELP` | Người này đăng nhập bằng mã gửi về email này. |
| `A_ERR_EMAIL_TAKEN` | Email này đã được dùng cho một tài khoản khác. |
| `A_STAFF_ADDED` | Đã thêm nhân viên. |
| `A_DEVICES_TITLE` | Thiết bị đăng nhập |
| `A_DEVICE_LAST_USED` | Dùng lần cuối: {datetime} |
| `A_DEVICE_THIS` | Máy này |
| `A_REVOKE` | Thu hồi |
| `A_REVOKE_TITLE` | Thu hồi {device} của {account}? |
| `A_REVOKE_BODY` | Máy này sẽ bị đăng xuất trong tối đa 5 phút và không nhận thông báo nữa. |
| `A_REVOKED` | Đã thu hồi máy. |
| `A_DEVICES_OWN_ONLY` | Bạn chỉ thấy các máy đăng nhập bằng tài khoản của mình. |
| `A_ACCOUNT_TITLE` | Tài khoản |
| `A_BACKUP_TITLE` | Email dự phòng |
| `A_BACKUP_INTRO` | Nếu mất điện thoại, bạn đăng nhập trên máy mới bằng hai mã: một gửi về email của bạn, một gửi về email dự phòng. |
| `A_BACKUP_NONE` | Chưa đăng ký |
| `A_F_BACKUP` | Email dự phòng mới |
| `A_BACKUP_CODE_PROMPT` | Nhập mã 6 số đã gửi về {email} để xác nhận |
| `A_CONFIRM_BACKUP` | Xác nhận email |
| `A_ERR_BACKUP_TAKEN` | Email dự phòng phải khác email đăng nhập và email của nhân viên. |
| `A_BACKUP_SAVED` | Đã lưu email dự phòng. |

## 8.7 Notifications

| Key | Vietnamese |
| --- | ---------- |
| `A_NOTIF_TITLE` | Đơn mới |
| `A_NOTIF_BODY` | {code}: {n} bánh, giao {date} |
| `A_NOTIF_CHANNEL` | Đơn mới |
| `A_NOTIF_PRIME` | Bật thông báo để biết ngay khi có đơn mới. Thông báo không chứa tên, số điện thoại hay địa chỉ của khách. |
| `A_NOTIF_ALLOW` | Bật thông báo |
| `A_NOTIF_LATER` | Để sau |
| `A_NOTIF_FOREGROUND` | Có đơn mới {code} |
