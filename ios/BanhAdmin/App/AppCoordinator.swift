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
    /// Order code of a notification tapped while signed out: kept in memory only, opened after sign-in (AC-43).
    private var pendingOrderCode: String?

    init(environment: AdminEnvironment) {
        self.environment = environment
        step = .email(makeEmailModel(email: ""))
    }

    /// App start: finish a sign-out the server has not confirmed, then open the session if there is one.
    func start() async {
        environment.router.listen { [weak self] event in self?.handle(event) }
        await environment.session.setOnEnded { [weak self] in Task { @MainActor [weak self] in self?.sessionEnded() } }
        let signOut = await environment.session.completePendingSignOut()
        let hasSession = await environment.session.hasSession
        if signOut == .offline, !hasSession { banner = AStrings.offlineSignOut }
        guard hasSession else { return showSignIn() }
        screen = .launching
        do {
            let me = try await environment.account.me()
            enter(SignedInUser(account: me.account, email: me.email, serverDate: me.serverDate), freshSignIn: false)
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
        ) { [weak self] user in self?.enter(user, freshSignIn: true) })
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

    /// `freshSignIn`: the notification permission is asked right after the first sign-in on this phone
    /// (FR-25); a restored session only refreshes the token when the permission is already granted.
    private func enter(_ user: SignedInUser, freshSignIn: Bool) {
        banner = nil
        let orders = OrdersCoordinator(user: user, environment: environment) { [weak self] in self?.signOut() }
        screen = .signedIn(orders)
        if let code = pendingOrderCode {
            pendingOrderCode = nil
            orders.openOrder(code: code)
        }
        Task { await environment.push.register(prompt: freshSignIn) }
    }

    private func handle(_ event: NotificationEvent) {
        guard case .signedIn(let orders) = screen else {
            if case .tapped(let code) = event { pendingOrderCode = code }
            return
        }
        switch event {
        case .tapped(let code): orders.openOrder(code: code)
        case .foreground(let code): orders.showForeground(code: code)
        }
    }

    /// A 401 that cannot be repaired: every model of the signed-in session is dropped, so no order or
    /// customer data stays in memory (BR-7).
    func sessionEnded() {
        environment.push.unregister()
        banner = AStrings.sessionEnded
        showSignIn()
    }

    /// The person signed out: forget this phone at once, tell the server afterwards.
    func signOut() {
        environment.push.unregister()
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
