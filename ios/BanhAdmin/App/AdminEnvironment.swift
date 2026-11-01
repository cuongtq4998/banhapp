import BanhCore
import Foundation

/// Composition root (ADR-0007: manual wiring, no DI framework). One instance lives as long as the process.
struct AdminEnvironment {
    let session: SessionManager
    let auth: any AuthService
    let orders: any OrdersAPI
    let account: any AccountAPI
    let opener: any URLOpener
    /// Debug stub only: the countdown of the resend button runs this fast.
    var tick: Duration = .seconds(1)

    @MainActor
    static func make(defaults: UserDefaults = .standard, bundle: Bundle = .main) -> AdminEnvironment {
        #if DEBUG
        if let stub = UITestStub.environment(for: defaults.string(forKey: AdminLaunch.stub)) { return stub }
        #endif
        let client = APIClient(
            baseURL: BuildConfiguration.apiBaseURL(in: bundle),
            appVersion: BuildConfiguration.appVersion(in: bundle),
            transport: URLSessionTransport()
        )
        return assemble(client: client, store: KeychainTokenStore(), opener: SystemURLOpener())
    }

    /// Wires the clients on one transport and one token store. The stub backend uses the same wiring.
    @MainActor
    static func assemble(client: APIClient, store: any TokenStore, opener: any URLOpener) -> AdminEnvironment {
        let session = SessionManager(client: client, store: store)
        return AdminEnvironment(
            session: session,
            auth: HTTPAuthService(
                client: client, session: session,
                installationID: InstallationID.current(), deviceName: InstallationID.deviceName()
            ),
            orders: HTTPOrdersAPI(client: client, session: session),
            account: HTTPAccountAPI(client: client, session: session),
            opener: opener
        )
    }
}
