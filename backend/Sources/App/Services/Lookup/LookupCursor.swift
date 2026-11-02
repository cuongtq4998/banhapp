import Foundation

/// Opaque paging position bound to one phone by a keyed hash.
struct LookupCursor: Equatable, Sendable {
    /// PostgreSQL keeps microseconds; whole units never mis-order ties.
    static let microsecondsPerSecond = 1_000_000.0

    let placedAtMicroseconds: Int64
    let orderID: UUID
    let page: Int

    private static let separator = "|"

    init(placedAtMicroseconds: Int64, orderID: UUID, page: Int) {
        self.placedAtMicroseconds = placedAtMicroseconds
        self.orderID = orderID
        self.page = page
    }

    init(placedAt: Date, orderID: UUID, page: Int) {
        self.init(
            placedAtMicroseconds: Int64((placedAt.timeIntervalSince1970 * Self.microsecondsPerSecond).rounded()),
            orderID: orderID, page: page)
    }

    /// For the in-memory test store only; the SQL uses the integer.
    var placedAt: Date { Date(timeIntervalSince1970: Double(placedAtMicroseconds) / Self.microsecondsPerSecond) }

    func encode(phone: String, hasher: LookupKeyHasher) -> String {
        let body = [String(placedAtMicroseconds), orderID.uuidString, String(page)].joined(separator: Self.separator)
        let tag = hasher.hash(phone + Self.separator + body)
        return Data((body + Self.separator + tag).utf8).base64EncodedString()
    }

    /// Nil for anything malformed, tampered or issued for another phone.
    static func decode(_ text: String, phone: String, hasher: LookupKeyHasher) -> LookupCursor? {
        guard let data = Data(base64Encoded: text), let raw = String(data: data, encoding: .utf8) else { return nil }
        let parts = raw.components(separatedBy: separator)
        guard parts.count == 4, let micros = Int64(parts[0]), let id = UUID(uuidString: parts[1]), let page = Int(parts[2]), page > 0,
              hasher.matches(parts[3], for: phone + separator + parts[0...2].joined(separator: separator)) else { return nil }
        return LookupCursor(placedAtMicroseconds: micros, orderID: id, page: page)
    }
}
