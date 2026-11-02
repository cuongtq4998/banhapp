import Foundation

/// Vietnamese texts of the two mails. The code mail holds the code only, no
/// link; the notice holds no code and no link (FR-1, FR-7).
enum MailTemplates {
    static func signInCode(to address: String, code: String) -> EmailMessage {
        EmailMessage(
            kind: .signInCode, to: address, subject: "Mã đăng nhập",
            body: "Mã đăng nhập của bạn là \(code). Mã có hiệu lực trong 10 phút và chỉ dùng một lần. "
                + "Nếu bạn không yêu cầu mã này, hãy bỏ qua e-mail."
        )
    }

    /// `deviceName` was validated (no control characters, 60 at most), so it
    /// cannot add a header line; the body is plain text.
    static func newDeviceNotice(to address: String, deviceName: String, at instant: Date) -> EmailMessage {
        EmailMessage(
            kind: .newDeviceNotice, to: address, subject: "Đăng nhập trên điện thoại mới",
            body: "Tài khoản chủ cửa hàng vừa đăng nhập trên một điện thoại mới: \(deviceName), lúc \(shopTime(instant)) (UTC+7). "
                + "Nếu không phải bạn, hãy mở ứng dụng và chọn \"Đăng xuất các điện thoại khác\"."
        )
    }

    private static func shopTime(_ instant: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: ShopCalendar.utcOffsetSeconds)
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: instant)
    }
}
