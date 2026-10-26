/// Whole dong with a dot as thousands separator, the dong sign and no decimals (design system
/// principle 4): 125000 becomes "125.000 ₫". Done by hand so the result never depends on the device locale.
nonisolated enum MoneyFormatter {
    private static let thousandsSeparator: Character = "."
    private static let digitsPerGroup = 3
    private static let currencySign = "₫"

    static func grouped(_ amountVND: Int) -> String {
        precondition(amountVND >= 0, "A price is never negative")
        let digits = Array(String(amountVND))
        var result: [Character] = []
        for (offset, digit) in digits.reversed().enumerated() {
            if offset > 0, offset.isMultiple(of: digitsPerGroup) { result.append(thousandsSeparator) }
            result.append(digit)
        }
        return String(result.reversed())
    }

    static func format(_ amountVND: Int) -> String {
        "\(grouped(amountVND)) \(currencySign)"
    }
}
