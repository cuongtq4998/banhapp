import BanhContracts
import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

@MainActor
struct SignInViewModelTests {
    @Test func emailFormatIsCheckedOnlyAfterTheFirstAttempt() async {
        let model = EmailViewModel(auth: FakeAuth()) { _, _ in }
        model.email = "not-an-email"
        #expect(model.visibleMessage == nil)
        await model.send()
        #expect(model.visibleMessage == .emailInvalid)
        #expect(!EmailViewModel.isValid("a@b"))
        #expect(EmailViewModel.isValid("nhanvien.a@example.com"))
    }

    @Test func sendTrimsAndLowercasesThenMovesOn() async {
        var sent: (String, Int)?
        let model = EmailViewModel(auth: FakeAuth()) { sent = ($0, $1) }
        model.email = "  Nhanvien.A@Example.com "
        await model.send()
        #expect(sent?.0 == "nhanvien.a@example.com")
        #expect(sent?.1 == 30)
    }

    @Test func rateLimitShowsMinutesRoundedUp() async {
        var auth = FakeAuth()
        auth.codeResult = .failure(APIError.service(code: "CODE_REQUEST_LIMIT", messageKey: "K", httpStatus: 429, details: ["retry_after_seconds": .int(1800)]))
        let model = EmailViewModel(email: "a@example.com", auth: auth) { _, _ in }
        await model.send()
        #expect(model.visibleMessage == .rateSend(minutes: 30))
    }

    @Test func offlineSendKeepsTheFieldAndSaysSo() async {
        var auth = FakeAuth()
        auth.codeResult = .failure(APIError.networkUnavailable)
        let model = EmailViewModel(email: "a@example.com", auth: auth) { _, _ in }
        await model.send()
        #expect(model.visibleMessage == .offline)
        #expect(model.email == "a@example.com")
    }

    private func codeModel(_ auth: FakeAuth, resend: Int = 30, signedIn: @escaping (SignedInUser) -> Void = { _ in }) -> CodeViewModel {
        CodeViewModel(email: "a@example.com", resendAfterSeconds: resend, auth: auth, sleep: { _ in }, onSignedIn: signedIn)
    }

    @Test func submitNeedsSixDigitsAndSignsIn() async {
        var user: SignedInUser?
        let model = codeModel(FakeAuth()) { user = $0 }
        model.code = "12345"
        #expect(!model.canSubmit)
        model.code = "123456"
        await model.submit()
        #expect(user?.account.role == .staff)
    }

    @Test func wrongAndExpiredCodesClearTheFieldAndShakeOnce() async {
        var auth = FakeAuth()
        auth.signInResult = .failure(APIError.service(code: "CODE_INVALID", messageKey: "K", httpStatus: 422, details: [:]))
        let model = codeModel(auth)
        model.code = "111111"
        await model.submit()
        #expect(model.message == .codeWrong)
        #expect(model.code.isEmpty)
        #expect(model.shakeCount == 1)
        auth.signInResult = .failure(APIError.service(code: "CODE_EXPIRED", messageKey: "K", httpStatus: 422, details: [:]))
        let expired = codeModel(auth)
        expired.code = "000000"
        await expired.submit()
        #expect(expired.message == .codeExpired)
    }

    @Test func resendWaitsThirtySecondsThenSendsAgain() async {
        let model = codeModel(FakeAuth(), resend: 3)
        #expect(!model.canResend)
        model.startCountdown()
        for _ in 0..<50 where model.resendRemaining > 0 { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(model.resendRemaining == 0)
        #expect(model.canResend)
        await model.resend()
        #expect(model.resendRemaining == 30)
    }
}
