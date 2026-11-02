import Foundation

/// Values of auth.md section 4.2 and ADR-0022. Constants, not settings: the
/// boundary tests pin them, and changing one is a decision of the documents.
enum AuthPolicy {
    static let codeLength = 6
    static let codeLifetime: TimeInterval = 600
    /// Wait between two codes for one address.
    static let resendWait: TimeInterval = 30
    static let codesPerHour = 3
    static let hourWindow: TimeInterval = 3_600
    /// The 5th wrong entry voids the code.
    static let maxWrongEntries = 5
    static let accessLifetime: TimeInterval = 300
    static let refreshLifetime: TimeInterval = 7 * 24 * 3_600
    /// A refresh credential is still accepted this long after it was replaced.
    static let refreshGrace: TimeInterval = 20
    static let codeRequestsPerClientPerHour = 20
    static let authRequestsPerClientPerHour = 60
    static let maxDeviceNameLength = 60
}
