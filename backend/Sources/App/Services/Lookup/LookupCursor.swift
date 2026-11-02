import Foundation

/// Opaque paging position bound to one phone by a keyed hash.
struct LookupCursor: Equatable, Sendable {
    let placedAt: Date
    let orderID: UUID
    let page: Int

    private static let separator = "|"

    func encode(phone: String, hasher: LookupKeyHasher) -> String {
        let body = [String(placedAt.timeIntervalSince1970), orderID.uuidString, String(page)].joined(separator: Self.separator)
        let tag = hasher.hash(phone + Self.separator + body)
        return Data((body + Self.separator + tag).utf8).base64EncodedString()
    }

    /// Nil for anything malformed, tampered or issued for another phone.
    static func decode(_ text: String, phone: String, hasher: LookupKeyHasher) -> LookupCursor? {
        guard let data = Data(base64Encoded: text), let raw = String(data: data, encoding: .utf8) else { return nil }
        let parts = raw.components(separatedBy: separator)
        guard parts.count == 4, let seconds = Double(parts[0]), let id = UUID(uuidString: parts[1]), let page = Int(parts[2]), page > 0,
              hasher.matches(parts[3], for: phone + separator + parts[0...2].joined(separator: separator)) else { return nil }
        return LookupCursor(placedAt: Date(timeIntervalSince1970: seconds), orderID: id, page: page)
    }
}
