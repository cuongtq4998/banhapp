import Foundation
import Observation

/// Root coordinator (MVVM-C): decides which part of the app shows (launch, sign-in, signed in), creates
/// the models and reacts to the end of a session. Screens never reach into the environment themselves.
@Observable
final class AppCoordinator {
    enum Screen {
        case launching
        case launchFailed
        case signIn
        case signedIn(OrdersCoordinator)
    }

    enum SignInStep {
        case email(EmailViewModel)
        case code(CodeViewModel)
    }

    private(set) var screen = Screen.launching
    private(set) var step: SignInStep!
    /// `A_SESSION_ENDED` or `A_OFFLINE_SIGNOUT` on the first sign-in screen.
    private(set) var banner: LocalizedStringResource?

    let environment: AdminEnvironment
    private var lastEmail = ""

    init(environment: AdminEnvironment) {
        self.environment = environment
        step = .email(makeEmailModel(email: ""))
    }

    /// App start: finish a sign-out the server has not confirmed, then open the session if there is one.
    func start() async {
        await environment.session.setOnEnded { [weak self] in Task { @MainActor [weak self] in self?.sessionEnded() } }
        let signOut = await environment.session.completePendingSignOut()
        let hasSession = await environment.session.hasSession
        if signOut == .offline, !hasSession { banner = AStrings.offlineSignOut }
        guard hasSession else { return showSignIn() }
        screen = .launching
        do {
            let me = try await environment.account.me()
            enter(SignedInUser(account: me.account, email: nil, serverDate: me.serverDate))
        } catch {
            if !(error is SessionEnded) { screen = .launchFailed }
        }
    }

    // MARK: Sign-in steps

    private func makeEmailModel(email: String) -> EmailViewModel {
        EmailViewModel(email: email, auth: environment.auth) { [weak self] email, resend in
            self?.lastEmail = email
            self?.showCode(email: email, resendAfter: resend)
        }
    }

    private func showCode(email: String, resendAfter: Int) {
        banner = nil
        step = .code(CodeViewModel(
            email: email, resendAfterSeconds: resendAfter, auth: environment.auth,
            sleep: { [tick = environment.tick] _ in try await Task.sleep(for: tick) }
        ) { [weak self] user in self?.enter(user) })
    }

    /// "Change e-mail" keeps the address (AC-3).
    func changeEmail() {
        step = .email(makeEmailModel(email: lastEmail))
    }

    private func showSignIn() {
        step = .email(makeEmailModel(email: ""))
        screen = .signIn
    }

    // MARK: Session

    private func enter(_ user: SignedInUser) {
        banner = nil
        screen = .signedIn(OrdersCoordinator(user: user, environment: environment) { [weak self] in self?.signOut() })
    }

    /// A 401 that cannot be repaired: every model of the signed-in session is dropped, so no order or
    /// customer data stays in memory (BR-7).
    func sessionEnded() {
        banner = AStrings.sessionEnded
        showSignIn()
    }

    /// The person signed out: forget this phone at once, tell the server afterwards.
    func signOut() {
        Task {
            await environment.session.clearLocalSession()
            banner = nil
            showSignIn()
            if await environment.session.completePendingSignOut() == .offline { banner = AStrings.offlineSignOut }
        }
    }

    func retryLaunch() {
        screen = .launching
        Task { await start() }
    }
}
