# Place Order UI, part 8: Content and copy keys (section 8)

[v1.6 | 2026-10-29] Privacy notice keys `PRIVACY_*`, `ERR_OPEN_PRIVACY`, `REVIEW_PRIVACY_LINK` added; `REVIEW_PRIVACY` now also names the note. [v1.5 | 2026-10-29] Part of the split UI specification; index: [place-order-ui.md](../place-order-ui.md). Section numbers are the original ones. Code comments cite this part as "place-order-ui.md section 8". Changes in v1.5: calendar, weekday, spoken-date and removed-cake-unknown keys added; `NOTE_COUNTER` and `ERR_NOTE_MAX` take {max}; `DETAIL_BTN_ORDER` decision recorded. Key names are the iOS String Catalog keys; Android resource names (`date_prev_month`, `date_weekday_n` and so on) may differ, the Vietnamese text must not.

## 8. Content & Copy

All display text is Vietnamese. Data-source values (shop name, greeting, cake names and descriptions, district names, slot times) come from the shop data and are not listed.

| Key | Vietnamese text | Used on |
| --- | --------------- | ------- |
| `LOGO_LABEL` | Logo cửa hàng | S-1, S-2 (screen reader) |
| `HOME_BTN_ZALO` | Zalo | S-2, S-9 |
| `HOME_BTN_PHONE` | Gọi điện | S-2, S-9 |
| `HOME_BTN_PRODUCTS` | Xem sản phẩm | S-2 |
| `HOME_BTN_ORDER` | Đặt bánh | S-2, S-3 [v1.3 | 2026-10-26] (board: same words on the S-2 card and the S-3 bar) |
| `HOME_PRODUCTS_SUB` | [v1.3 | 2026-10-26] {n} loại bánh tét (board: "4 loại bánh tét"; {n} is the number of active cakes, never typed in; see BQ-4) | S-2 |
| `HOME_ORDER_SUB` | [v1.3 | 2026-10-26] Chọn bánh, ngày giờ và địa chỉ | S-2 |
| `HOME_BTN_ZALO_NUMBER` | [v1.3 | 2026-10-26] Zalo {number} (board: "Zalo [Số Zalo]"; {number} is the shop's Zalo number from shop data; when the number is missing the button shows `HOME_BTN_ZALO`) | S-2 |
| `HOME_BTN_PHONE_NUMBER` | [v1.3 | 2026-10-26] {number} (board: "[Số điện thoại]"; the shop's phone number from shop data; when missing the button shows `HOME_BTN_PHONE`) | S-2 |
| `HOME_BTN_ZALO_A11Y` | [v1.3 | 2026-10-26] Nhắn Zalo cho cửa hàng, số {number} | S-2 (screen reader) |
| `HOME_BTN_PHONE_A11Y` | [v1.3 | 2026-10-26] Gọi điện cho cửa hàng, số {number} | S-2 (screen reader) |
| `BACK_TO_HOME` | [v1.3 | 2026-10-26] Quay lại trang chủ (board `aria-label`) | S-3 back button (screen reader) |
| `BACK_TO_LIST` | [v1.3 | 2026-10-26] Quay lại danh sách (board `aria-label`) | S-4 back button (screen reader) |
| `HOME_ERR` | Không tải được thông tin cửa hàng. Vui lòng kiểm tra kết nối mạng và thử lại. | S-2 |
| `ERR_OPEN_ZALO` | Không mở được Zalo. Bạn có thể gọi điện cho cửa hàng. | S-2, S-9 |
| `ERR_OPEN_PHONE` | Không mở được ứng dụng gọi điện. | S-2, S-9 |
| `ERR_NETWORK_LOAD` | Không có kết nối mạng. Vui lòng kiểm tra kết nối và thử lại. | S-3 to S-7 |
| `COMMON_RETRY` | Thử lại | all error states |
| `COMMON_BACK` | Quay lại | back control (screen reader label) |
| `COMMON_NEXT` | Tiếp tục | S-5, S-6, S-7 |
| `COMMON_EDIT` | Sửa | S-8 |
| `COMMON_LOADING` | Đang tải | loading states (screen reader) |
| `PRODUCTS_TITLE` | Sản phẩm | S-3 |
| `PRODUCTS_ERR` | Không tải được thông tin bánh. Vui lòng thử lại. | S-3, S-5 [v1.2 | 2026-10-26] (S-4 removed) |
| `PRODUCTS_EMPTY` | [v1.2 | 2026-10-26] Hiện cửa hàng chưa có bánh để đặt. Vui lòng quay lại sau hoặc liên hệ cửa hàng qua Zalo hoặc điện thoại. | S-3, S-5 |
| `HOME_NO_CAKES` | [v1.2 | 2026-10-26] Hiện cửa hàng chưa có bánh để đặt. Bạn có thể liên hệ cửa hàng qua Zalo hoặc gọi điện. | S-2 |
| `DETAIL_GONE` | [v1.2 | 2026-10-26] Bánh này hiện không còn được bán. | S-4 |
| `DETAIL_GONE_ACTION` | [v1.2 | 2026-10-26] Xem các bánh khác | S-4 |
| `ORDER_CAKE_REMOVED` | [v1.2 | 2026-10-26] {name} hiện không còn được bán và đã được bỏ khỏi đơn. Các bánh khác và thông tin bạn đã nhập vẫn được giữ lại. | S-5 |
| `ORDER_CAKE_REMOVED_UNKNOWN` | [v1.5 | 2026-10-29] Một loại bánh (used as {name} of `ORDER_CAKE_REMOVED` when the removed cake was never seen in this run, for example after a restored draft) | S-5 |
| `MONEY_FORMAT` | [v1.2 | 2026-10-26] {amount} ₫ (the amount is already grouped with dots, whole dong; code: Android `money_format` `%1$s ₫`) | every price, subtotal, fee and total |
| `PRODUCT_IMG_FAILED` | Không tải được ảnh | S-3, S-4 |
| `PRICE_EACH` | {amount}/cái | S-3, S-4, S-5 |
| `DETAIL_BTN_ORDER` | [v1.3 | 2026-10-26] Đặt bánh (was "Đặt bánh này"; the board's S-4 bar button reads "Đặt bánh") [v1.5 | 2026-10-29] Confirmed: this text wins, screen design 5.4 and the board agree; iOS and Android code still read "Đặt bánh này" and must change | S-4 |
| `FLOW_TITLE` | Đặt bánh | S-5 to S-8 |
| `STEP_LABEL` | Bước {n}/4 ([v1.2 | 2026-10-26] the total 4 is part of the string, as in Android `step_label` `Bước %1$d/4`; the step count is fixed by G-1) | S-5 to S-8 |
| `STEP1` | Chọn bánh | S-5 |
| `STEP2` | Ngày và giờ nhận | S-6 |
| `STEP3` | Người nhận và địa chỉ | S-7 |
| `STEP4` | Xem lại đơn hàng | S-8 |
| `QTY_TOTAL` | Tổng số bánh: {n} | S-5 |
| `QTY_SUBTOTAL` | Tiền bánh: {amount} | S-5 |
| `QTY_MIN_HINT` | Đơn hàng cần ít nhất {min} bánh. | S-5 |
| `QTY_INC_A11Y` | Tăng số lượng {name} | S-5 |
| `QTY_DEC_A11Y` | Giảm số lượng {name} | S-5 |
| `QTY_VALUE_A11Y` | {name}, số lượng {n} | S-5 |
| `DATE_TITLE` | Chọn ngày nhận | S-6 |
| `DATE_HINT_RANGE` | Nhận bánh từ {from} đến {to}. | S-6 |
| `DATE_LEGEND_FULL` | Ngày gạch chéo không còn đủ chỗ cho đơn của bạn. | S-6 |
| `DATE_A11Y_SELECTED` | {date}, đã chọn | S-6 |
| `DATE_A11Y_FULL` | {date}, không còn đủ chỗ cho đơn này | S-6 |
| `DATE_A11Y_TOO_SOON` | {date}, chưa thể chọn vì cần đặt trước ít nhất {days} ngày | S-6 |
| `DATE_A11Y_TOO_FAR` | {date}, chưa thể chọn vì chỉ nhận đặt trước tối đa {max} ngày | S-6 |
| `DATE_EMPTY` | Không có ngày nào còn đủ chỗ cho đơn của bạn. Hãy giảm số lượng bánh. | S-6 |
| `DATE_EMPTY_ACTION` | Sửa số lượng | S-6, S-8 |
| `DATE_MONTH_TITLE` | [v1.5 | 2026-10-29] Tháng {m} năm {y} (month title above the grid; {m} is 1 to 12 without a leading zero) | S-6 |
| `DATE_MONTH_PREV` | [v1.5 | 2026-10-29] Tháng trước (screen reader label of the previous-month control) | S-6 |
| `DATE_MONTH_NEXT` | [v1.5 | 2026-10-29] Tháng sau (screen reader label of the next-month control) | S-6 |
| `WEEKDAY_1` to `WEEKDAY_7` | [v1.5 | 2026-10-29] T2, T3, T4, T5, T6, T7, CN (Monday first; `WEEKDAY_1` = T2 ... `WEEKDAY_6` = T7, `WEEKDAY_7` = CN) | S-6 (grid header) |
| `DATE_A11Y_AVAILABLE` | [v1.5 | 2026-10-29] {date}, có thể chọn (both platforms read it for a selectable, unselected day) | S-6 (screen reader) |
| `DATE_SPOKEN` | [v1.5 | 2026-10-29] ngày {d} tháng {m} năm {y} (the spoken {date} inside every `DATE_A11Y_*` text; the visible date stays dd/MM/yyyy, FR-21) | S-6 (screen reader) |
| `DATE_ERR` | Không tải được lịch nhận bánh. Vui lòng thử lại. | S-6 |
| `DATE_CLEARED` | Ngày bạn chọn không còn đủ chỗ cho đơn của bạn. Vui lòng chọn ngày khác. | S-6 |
| `TIME_TITLE` | Chọn giờ nhận | S-6 |
| `SLOT_LABEL` | {start} – {end} | S-6, S-8 |
| `NEXT_HINT_DATE_TIME` | Chọn ngày và giờ nhận để tiếp tục. | S-6 |
| `FIELD_NAME` | Họ và tên | S-7 |
| `FIELD_PHONE` | Số điện thoại | S-7 |
| `FIELD_ADDRESS` | Địa chỉ giao hàng | S-7 |
| `FIELD_DISTRICT` | Quận/huyện | S-7 |
| `DISTRICT_PLACEHOLDER` | Chọn quận/huyện | S-7 |
| `DISTRICT_FEE` | Phí giao hàng: {amount} | S-7 |
| `DISTRICT_ERR` | Không tải được danh sách khu vực giao hàng. | S-7 |
| `DISTRICT_EMPTY` | Hiện chưa có khu vực giao hàng nào. Vui lòng liên hệ cửa hàng. | S-7 |
| `FIELD_NOTE` | Ghi chú (không bắt buộc) | S-7 |
| `NOTE_COUNTER` | [v1.5 | 2026-10-29] {n}/{max} ({max} is `settings.note_max_length` from the catalog; fallback 200 when the setting is missing; never typed in) | S-7 |
| `ERR_NAME_REQUIRED` | Vui lòng nhập họ và tên. | S-7 |
| `ERR_PHONE_REQUIRED` | Vui lòng nhập số điện thoại. | S-7 |
| `ERR_PHONE_INVALID` | [v1.1 | 2026-10-25] Vui lòng nhập số điện thoại di động Việt Nam (10 số, ví dụ 09xx xxx xxx). | S-7 |
| `ERR_ADDRESS_REQUIRED` | Vui lòng nhập địa chỉ giao hàng. | S-7 |
| `ERR_DISTRICT_REQUIRED` | Vui lòng chọn quận/huyện. | S-7 |
| `ERR_NOTE_MAX` | [v1.5 | 2026-10-29] Ghi chú tối đa {max} ký tự. ({max} as in `NOTE_COUNTER`) | S-7 |
| `REVIEW_SEC_CAKES` | Bánh đã chọn | S-8 |
| `REVIEW_ITEM` | {name} × {n} | S-8 |
| `REVIEW_FEE` | Phí giao hàng | S-8 |
| `REVIEW_TOTAL` | Tổng cộng | S-8 |
| `REVIEW_DATE` | Ngày nhận | S-8 |
| `REVIEW_TIME` | Giờ nhận | S-8 |
| `REVIEW_NAME` | Người nhận | S-8 |
| `REVIEW_PHONE` | Số điện thoại | S-8 |
| `REVIEW_ADDRESS` | Địa chỉ giao hàng | S-8 |
| `REVIEW_NOTE` | Ghi chú | S-8 |
| `PRIVACY_TITLE` | [v1.6 | 2026-10-29] Thông tin của bạn được dùng như thế nào | S-7 |
| `PRIVACY_BODY` | [v1.6 | 2026-10-29] Để giao bánh, cửa hàng cần họ tên, số điện thoại, địa chỉ giao hàng và ghi chú (nếu bạn nhập). Cửa hàng chỉ dùng các thông tin này để giao đơn hàng và liên hệ với bạn. | S-7 |
| `PRIVACY_DRAFT` | [v1.6 | 2026-10-29] Bản nháp đơn hàng chỉ được lưu trên điện thoại của bạn và tự xoá sau 24 giờ. | S-7 |
| `PRIVACY_LINK` | [v1.6 | 2026-10-29] Xem chính sách quyền riêng tư đầy đủ | S-7 |
| `PRIVACY_LINK_A11Y_HINT` | [v1.6 | 2026-10-29] Mở trang chính sách trong trình duyệt | S-7, S-8 |
| `ERR_OPEN_PRIVACY` | [v1.6 | 2026-10-29] Không mở được trang chính sách. Vui lòng thử lại sau. | S-7, S-8 |
| `REVIEW_PRIVACY` | [v1.6 | 2026-10-29] Chúng tôi chỉ dùng họ tên, số điện thoại, địa chỉ và ghi chú của bạn để giao đơn hàng này và liên hệ với bạn. | S-8 |
| `REVIEW_PRIVACY_LINK` | [v1.6 | 2026-10-29] Xem chính sách đầy đủ | S-8 |
| `BTN_CONFIRM` | Xác nhận đơn hàng | S-8 |
| `BTN_SENDING` | Đang gửi đơn | S-8 |
| `ERR_MIN_QTY` | Đơn hàng cần ít nhất {min} bánh. Vui lòng thêm bánh. | S-8 |
| `ERR_DATE_CAPACITY` | Ngày {date} không còn đủ chỗ cho đơn của bạn. Vui lòng chọn ngày khác. | S-8 |
| `ERR_DATE_LEAD` | Ngày nhận phải sau ngày đặt ít nhất {days} ngày. Vui lòng chọn ngày khác. | S-8 |
| `ERR_DATE_HORIZON` | Chỉ nhận đặt trước tối đa {max} ngày. Vui lòng chọn ngày sớm hơn. | S-8 |
| `ERR_DISTRICT_UNSERVED` | Cửa hàng chưa giao đến khu vực này. Vui lòng chọn quận/huyện khác. | S-8 |
| `ACTION_CHOOSE_DATE` | Chọn ngày khác | S-8 |
| `ACTION_CHOOSE_DISTRICT` | Chọn khu vực khác | S-8 |
| `ACTION_CHOOSE_SLOT` | [v1.1 | 2026-10-25] Chọn giờ khác | S-8 |
| `ERR_PRODUCT_UNAVAILABLE` | [v1.1 | 2026-10-25] Có bánh trong đơn hiện không còn được bán. Vui lòng chọn lại bánh. [v1.2 | 2026-10-26] Đơn hàng chưa được gửi. Thông tin của bạn vẫn được giữ lại. | S-8 |
| `ERR_SLOT_UNAVAILABLE` | [v1.1 | 2026-10-25] Khung giờ nhận bánh bạn chọn không còn khả dụng. Vui lòng chọn giờ khác. | S-8 |
| `ERR_RATE_LIMITED` | [v1.1 | 2026-10-25] Đơn hàng chưa được gửi vì có quá nhiều yêu cầu. Thông tin của bạn vẫn được giữ lại. Vui lòng đợi một lát rồi thử lại. | S-8 |
| `ERR_OFFLINE` | Đơn hàng chưa được gửi vì không có kết nối mạng. Thông tin của bạn vẫn được giữ lại. | S-8 |
| `ERR_SERVER` | Đơn hàng chưa được gửi do có lỗi. Thông tin của bạn vẫn được giữ lại. Vui lòng thử lại. | S-8 |
| `ERR_TIMEOUT` | Đơn hàng chưa được gửi vì mất quá nhiều thời gian. Thông tin của bạn vẫn được giữ lại. Vui lòng thử lại. | S-8 |
| `MSG_PRICE_CHANGED` | [v1.1 | 2026-10-25] Giá đã thay đổi nên đơn hàng chưa được gửi. Vui lòng xem lại giá và tổng cộng mới, rồi bấm xác nhận lại. | S-8 |
| `CONF_TITLE` | Đã nhận đơn hàng | S-9 |
| `CONF_CODE_LABEL` | Mã đơn hàng | S-9 |
| `CONF_CODE_A11Y` | Mã đơn hàng {code} | S-9 |
| `CONF_MESSAGE` | Cửa hàng đã nhận được đơn của bạn và sẽ liên hệ với bạn. Khi cần, bạn có thể nhắn Zalo hoặc gọi điện cho cửa hàng và cho biết mã đơn hàng. | S-9 |
| `CONF_BTN_HOME` | Về trang chủ | S-9 |

Copy check: no key contains payment wording (FR-19); `CONF_MESSAGE` says received and contact, not accepted (AC-25). [v1.1 | 2026-10-25] No key is pending; all error codes of api.md section 5 that need display text have a key (`ERR_PRODUCT_UNAVAILABLE`, `ERR_SLOT_UNAVAILABLE`, `ERR_RATE_LIMITED` added; other codes use `ERR_SERVER`). `HOME_BTN_ZALO` stays the plain word "Zalo".
