import Foundation
import Observation

/// S-A1: asks for a one-time code. Same next step whether or not the address is registered (FR-1).
@Observable
final class EmailViewModel {
    var email: String
    private(set) var isSending = false
    private(set) var message: SignInMessage?
    private var attempted = false

    private let auth: any AuthService
    private let onCodeSent: (_ email: String, _ resendAfterSeconds: Int) -> Void

    init(email: String = "", auth: any AuthService, onCodeSent: @escaping (String, Int) -> Void) {
        self.email = email
        self.auth = auth
        self.onCodeSent = onCodeSent
    }

    var trimmed: String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    var canSend: Bool { !trimmed.isEmpty && !isSending }

    /// Format only (BR-4): something, "@", a domain with a dot, no spaces, at most 254 characters.
    static func isValid(_ address: String) -> Bool {
        guard address.count <= 254, !address.contains(" ") else { return false }
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }

    /// Shown under the field after the first send attempt.
    var visibleMessage: SignInMessage? {
        if let message { return message }
        return attempted && !Self.isValid(trimmed) ? .emailInvalid : nil
    }

    func send() async {
        attempted = true
        message = nil
        guard Self.isValid(trimmed) else { return }
        isSending = true
        defer { isSending = false }
        do {
            let response = try await auth.requestCode(email: trimmed)
            onCodeSent(trimmed, response.resendAfterSeconds)
        } catch {
            message = SignInMessage.forRequest(error)
        }
    }
}
