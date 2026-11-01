#if DEBUG
import BanhCore
import Foundation

/// The debug stub backend, chosen by the launch argument `-BanhAdminStub <mode>`. Compiled into debug
/// builds only, so a release build cannot be pointed away from the real API. Modes: `AdminLaunch`.
enum UITestStub {
    private static let signedInModes: Set<String> = [
        AdminLaunch.modeStaff, AdminLaunch.modeOwner, AdminLaunch.modeConflict, AdminLaunch.modeRefresh,
        AdminLaunch.modeRevoked, AdminLaunch.modeOffline, AdminLaunch.modeEmpty, AdminLaunch.modeGone,
        AdminLaunch.modeServerError,
    ]

    @MainActor
    static func environment(for mode: String?) -> AdminEnvironment? {
        guard let mode, signedInModes.contains(mode) || mode == AdminLaunch.modeSignIn || mode == AdminLaunch.modeSignInOwner
        else { return nil }
        let transport = StubAdminTransport(mode: mode)
        let store = InMemoryTokenStore(refreshToken: signedInModes.contains(mode) ? transport.initialRefreshToken : nil)
        let client = APIClient(baseURL: URL(string: "http://stub.invalid")!, appVersion: "1.0.0", transport: transport)
        return AdminEnvironment.assemble(client: client, store: store, opener: AcceptingURLOpener())
    }
}
#endif
