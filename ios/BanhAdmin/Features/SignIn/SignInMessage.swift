import BanhCore
import Foundation

/// What the sign-in screens say about a failed step. Chosen from the error, shown as text.
enum SignInMessage: Equatable {
    case emailInvalid
    case rateSend(minutes: Int)
    case generic
    case offline
    case codeWrong
    case codeExpired

    var text: String {
        switch self {
        case .emailInvalid: String(localized: AStrings.errEmailInvalid)
        case .rateSend(let minutes): AStrings.rateSend(minutes: minutes)
        case .generic: String(localized: AStrings.errGeneric)
        case .offline: String(localized: AStrings.offlineSave)
        case .codeWrong: String(localized: AStrings.codeWrong)
        case .codeExpired: String(localized: AStrings.codeExpired)
        }
    }

    /// Request errors (send and resend); `nil` for a plain "wait" answer, which only restarts the countdown.
    static func forRequest(_ error: Error) -> SignInMessage {
        guard let error = error as? APIError else { return .generic }
        if error.isConnectivity { return .offline }
        switch error.code {
        case "CODE_REQUEST_LIMIT":
            return .rateSend(minutes: max(1, Int((Double(error.retryAfterSeconds ?? 3600) / 60).rounded(.up))))
        case "VALIDATION_FAILED": return .emailInvalid
        default: return .generic
        }
    }

    static func forSignIn(_ error: Error) -> SignInMessage {
        guard let error = error as? APIError else { return .generic }
        if error.isConnectivity { return .offline }
        switch error.code {
        case "CODE_INVALID": return .codeWrong
        case "CODE_EXPIRED": return .codeExpired
        default: return .generic
        }
    }
}
