import Foundation

/// Keyset position of the list (ADR-0029): the four sort keys
/// (list date first, order-process.md section 4) of the last row,
/// as the database printed them, behind a version number, in an opaque
/// base64url string. The keys of an order never change, so a page never
/// repeats a row; a cursor of another version is refused.
struct OrderCursor: Sendable, Equatable {
    /// Payload version; a bump makes every older cursor invalid.
    static let version = 2

    let listDate: String
    let slotStart: String
    let createdAt: String
    let id: String

    var token: String {
        let joined = [String(Self.version), listDate, slotStart, createdAt, id].joined(separator: "|")
        return Data(joined.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Nil for anything that is not exactly what `token` produces.
    init?(token: String) {
        var base64 = token.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), let text = String(data: data, encoding: .utf8) else { return nil }
        let parts = text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5, Int(parts[0]) == Self.version, BusinessDate(isoString: parts[1]) != nil,
              Self.matches(parts[2], #"^\d\d:\d\d:\d\d$"#),
              Self.matches(parts[3], #"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z$"#),
              UUID(uuidString: parts[4]) != nil else { return nil }
        (listDate, slotStart, createdAt, id) = (parts[1], parts[2], parts[3], parts[4])
    }

    init(listDate: String, slotStart: String, createdAt: String, id: String) {
        (self.listDate, self.slotStart, self.createdAt, self.id) = (listDate, slotStart, createdAt, id)
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
