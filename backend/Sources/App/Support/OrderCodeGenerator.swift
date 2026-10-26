/// Order code format of ADR-0009: `BT-` plus 6 characters from a 31-character
/// alphabet without 0, 1, I, L, O, so a customer can dictate it.
enum OrderCodeFormat {
    static let prefix = "BT-"
    static let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
    static let randomLength = 6
    /// The same rule as the CHECK on `customer_order.order_code`.
    static let pattern = "^BT-[2-9A-HJKMNP-Z]{6}$"
}

protocol OrderCodeGenerator: Sendable {
    func makeCode() -> String
}

/// Draws each character from a cryptographically secure source (ADR-0009: the
/// code must not be guessable). Collisions are the caller's concern: the
/// unique index is the guarantee and the order service retries.
struct RandomOrderCodeGenerator: OrderCodeGenerator {
    /// Returns an index in `0..<upperBound`; replaceable in tests.
    let randomIndex: @Sendable (Int) -> Int

    init(randomIndex: @escaping @Sendable (Int) -> Int = { upperBound in
        // SystemRandomNumberGenerator is cryptographically secure on every
        // platform Swift supports.
        var source = SystemRandomNumberGenerator()
        return Int.random(in: 0..<upperBound, using: &source)
    }) {
        self.randomIndex = randomIndex
    }

    func makeCode() -> String {
        let alphabet = OrderCodeFormat.alphabet
        let suffix = (0..<OrderCodeFormat.randomLength).map { _ in alphabet[randomIndex(alphabet.count)] }
        return OrderCodeFormat.prefix + String(suffix)
    }
}
