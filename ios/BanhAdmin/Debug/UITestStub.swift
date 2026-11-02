#if DEBUG
import BanhCore
import Foundation

/// The debug stub backend, chosen by the launch argument `-BanhAdminStub <mode>`. Compiled into debug
/// builds only, so a release build cannot be pointed away from the real API. Modes: `AdminLaunch`.
enum UITestStub {
    private static let signedInModes: Set<String> = [
        AdminLaunch.modeStaff, AdminLaunch.modeOwner, AdminLaunch.modeConflict, AdminLaunch.modeRefresh,
        AdminLaunch.modeRevoked, AdminLaunch.modeOffline, AdminLaunch.modeEmpty, AdminLaunch.modeGone,
        AdminLaunch.modeServerError, AdminLaunch.modeOwnerFull, AdminLaunch.modeOwnerOffline, AdminLaunch.modeOwnerError,
        AdminLaunch.modeOwnerSlow,
    ]

    @MainActor
    static func environment(for mode: String?) -> AdminEnvironment? {
        guard let mode, signedInModes.contains(mode) || mode == AdminLaunch.modeSignIn || mode == AdminLaunch.modeSignInOwner
        else { return nil }
        let transport = StubAdminTransport(mode: mode)
        let store = InMemoryTokenStore(refreshToken: signedInModes.contains(mode) ? transport.initialRefreshToken : nil)
        let client = APIClient(baseURL: URL(string: "http://stub.invalid")!, appVersion: "1.0.0", transport: transport)
        let environment = AdminEnvironment.assemble(
            client: client, store: store, opener: AcceptingURLOpener(), tokens: FakeTokenProvider()
        )
        simulatePush(UserDefaults.standard.string(forKey: AdminPushLaunch.key), router: environment.router)
        return environment
    }

    /// `tap:<code>` is queued at once (the app "opened from a notification"); `foreground:<code>` arrives 2 s later.
    @MainActor
    private static func simulatePush(_ argument: String?, router: NotificationRouter) {
        guard let parts = argument?.split(separator: ":", maxSplits: 1).map(String.init), parts.count == 2 else { return }
        switch parts[0] {
        case "tap": router.deliver(.tapped(orderCode: parts[1]))
        case "foreground":
            Task {
                try? await Task.sleep(for: .seconds(2))
                router.deliver(.foreground(orderCode: parts[1]))
            }
        default: break
        }
    }
}
#endif
