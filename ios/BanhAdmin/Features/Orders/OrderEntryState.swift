import BanhCore
import Foundation

/// Bounds and rules of the fee entry (api/09 10.13.1).
nonisolated enum FeeRules {
    static let maxVnd = 10_000_000
}

/// The date sheet (schedule or change): the window is the server's, never the device clock.
nonisolated struct DateEntry: Equatable, Sendable {
    let range: DateRange?
    /// The stored date when changing; nil when scheduling.
    let current: String?
    var chosen: String

    init(range: DateRange?, current: String?) {
        self.range = range
        self.current = current
        chosen = current ?? range?.min ?? ""
    }

    /// ISO dates compare as text; the range comes from the server.
    var isInRange: Bool {
        guard let range else { return false }
        return chosen >= range.min && chosen <= range.max
    }

    var canSave: Bool { isInRange && chosen != current }
}

/// The fee sheet (start delivery or correction): whole VND, no prefill, 0 is a fee.
nonisolated struct FeeEntryState: Equatable, Sendable {
    /// The fee being corrected; nil when starting delivery.
    let previous: Int?
    let cakesSubtotalVnd: Int
    var text = ""

    var fee: Int? {
        let digits = text.trimmingCharacters(in: .whitespaces)
        guard !digits.isEmpty, digits.allSatisfy(\.isASCIIDigit) else { return nil }
        return Int(digits)
    }

    var isValid: Bool { fee.map { (0...FeeRules.maxVnd).contains($0) } ?? false }
    var canSave: Bool { isValid && fee != previous }
    /// Cakes plus fee, shown only inside the sheet while typing.
    var preview: Int? { isValid ? fee.map { cakesSubtotalVnd + $0 } : nil }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

/// A refusal the sheet can show next to its field (api/09 10.13.1, .2 and .6).
nonisolated enum EntryError: Equatable, Sendable {
    case datePast, dateTooFar(DateRange?), dateUnchanged
    case feeInvalid, feeRequired, feeUnchanged
    case feeCorrectionNotAllowed, transitionInvalid
    case other

    init(_ error: APIError) {
        let codes = Set(error.fieldProblems.map(\.code) + [error.code].compactMap { $0 })
        if codes.contains("EXPECTED_DATE_PAST") { self = .datePast }
        else if codes.contains("EXPECTED_DATE_TOO_FAR") { self = .dateTooFar(Self.range(of: error)) }
        else if codes.contains("EXPECTED_DATE_UNCHANGED") { self = .dateUnchanged }
        else if codes.contains("FEE_INVALID") { self = .feeInvalid }
        else if codes.contains("FEE_REQUIRED") { self = .feeRequired }
        else if codes.contains("FEE_UNCHANGED") { self = .feeUnchanged }
        else if codes.contains("FEE_CORRECTION_NOT_ALLOWED") { self = .feeCorrectionNotAllowed }
        else if codes.contains("STATUS_TRANSITION_INVALID") { self = .transitionInvalid }
        else { self = .other }
    }

    private static func range(of error: APIError) -> DateRange? {
        guard case .service(_, _, _, let details) = error, let value = details["expected_date_range"],
              let data = try? JSONEncoder().encode(value) else { return nil }
        return try? APIClient.decoder.decode(DateRange.self, from: data)
    }
}
