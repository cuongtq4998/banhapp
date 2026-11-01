import BanhCore
import Foundation
import Observation

/// S-A2: the six digits. Resend waits 30 s after each code (AC-3); the sixth digit does not submit.
@Observable
final class CodeViewModel {
    let email: String
    var code = "" { didSet { if code != oldValue, !code.isEmpty { message = nil } } }
    private(set) var message: SignInMessage?
    private(set) var isSubmitting = false
    private(set) var isResending = false
    private(set) var resendRemaining: Int
    /// Counts up on a refused code; the field shakes once per step.
    private(set) var shakeCount = 0

    private let auth: any AuthService
    private let sleep: @Sendable (Duration) async throws -> Void
    private let onSignedIn: (SignedInUser) -> Void
    private var countdown: Task<Void, Never>?

    init(
        email: String, resendAfterSeconds: Int, auth: any AuthService,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onSignedIn: @escaping (SignedInUser) -> Void
    ) {
        self.email = email
        self.auth = auth
        self.sleep = sleep
        self.onSignedIn = onSignedIn
        resendRemaining = resendAfterSeconds
    }

    var canSubmit: Bool { code.count == 6 && !isSubmitting }
    var canResend: Bool { resendRemaining == 0 && !isResending && !isSubmitting }

    func startCountdown() {
        countdown?.cancel()
        countdown = Task { [weak self] in
            while let self, self.resendRemaining > 0 {
                do { try await self.sleep(.seconds(1)) } catch { return }
                self.resendRemaining -= 1
            }
        }
    }

    func stopCountdown() { countdown?.cancel() }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        message = nil
        defer { isSubmitting = false }
        do {
            onSignedIn(try await auth.signIn(email: email, code: code))
        } catch {
            guard !(error is SessionEnded) else { return }
            fail(SignInMessage.forSignIn(error))
        }
    }

    func resend() async {
        guard canResend else { return }
        isResending = true
        defer { isResending = false }
        do {
            let response = try await auth.requestCode(email: email)
            code = ""
            message = nil
            resendRemaining = response.resendAfterSeconds
            startCountdown()
        } catch let error as APIError where error.code == "CODE_RESEND_WAIT" {
            resendRemaining = error.retryAfterSeconds ?? 30
            startCountdown()
        } catch {
            message = SignInMessage.forRequest(error)
        }
    }

    private func fail(_ failure: SignInMessage) {
        message = failure
        if failure == .codeWrong || failure == .codeExpired {
            code = ""
            message = failure
            shakeCount += 1
        }
    }
}
