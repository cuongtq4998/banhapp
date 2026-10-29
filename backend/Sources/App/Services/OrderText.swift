import Foundation

/// Text rules of ADR-0009: NFC, trimmed, length in Unicode code points, no
/// control characters (a newline is allowed where the field says so).
enum OrderText {
    static let nameMaxLength = 100
    static let addressMaxLength = 250

    enum Failure: Error, Equatable {
        case empty
        case tooLong
        case controlCharacter
    }

    /// The normalised text, or why it is not acceptable. `minLength` is 1 for
    /// required fields and 0 for the note.
    static func normalise(
        _ raw: String, minLength: Int, maxLength: Int, allowsNewline: Bool
    ) -> Result<String, Failure> {
        let text = raw.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasControl = text.unicodeScalars.contains { scalar in
            scalar.properties.generalCategory == .control && !(allowsNewline && scalar == "\n")
        }
        if hasControl { return .failure(.controlCharacter) }
        let length = text.unicodeScalars.count
        if length < minLength { return .failure(.empty) }
        if length > maxLength { return .failure(.tooLong) }
        return .success(text)
    }
}
