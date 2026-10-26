import Foundation

/// Identifier of a catalogue resource (`product_id`, `district_id`, `slot_id`).
///
/// A type of its own, not a bare `UUID`, because `UUID` encodes in upper case
/// while the contract (api.md, RFC 4122 output form) writes lower case; one
/// place guarantees the wire form so every response, and therefore every
/// `ETag`, is byte-stable. Decoding accepts either case.
public struct ResourceID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let uuid: UUID

    public init(_ uuid: UUID) {
        self.uuid = uuid
    }

    public var description: String { uuid.uuidString.lowercased() }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let uuid = UUID(uuidString: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a UUID")
        }
        self.uuid = uuid
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
