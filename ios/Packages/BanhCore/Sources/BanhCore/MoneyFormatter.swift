/// Whole dong with a dot as thousands separator and the dong sign: 125000 becomes "125.000 ₫".
/// Done by hand so the result never depends on the device locale.
public enum MoneyFormatter {
    public static func grouped(_ amountVND: Int) -> String {
        let digits = Array(String(abs(amountVND)))
        var result: [Character] = []
        for (offset, digit) in digits.reversed().enumerated() {
            if offset > 0, offset.isMultiple(of: 3) { result.append(".") }
            result.append(digit)
        }
        return (amountVND < 0 ? "-" : "") + String(result.reversed())
    }

    public static func format(_ amountVND: Int) -> String {
        "\(grouped(amountVND)) ₫"
    }
}
