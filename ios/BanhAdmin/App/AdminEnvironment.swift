import BanhCore
import Foundation

/// Composition root (ADR-0007: manual wiring, no DI framework). One instance lives as long as the process.
struct AdminEnvironment {
    let session: SessionManager
    let auth: any AuthService
    let orders: any OrdersAPI
    let account: any AccountAPI
    let owner: any OwnerAPI
    /// Host of `image_url` paths.
    let baseURL: URL
    let push: PushRegistrar
    let router: NotificationRouter
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
        let store = KeychainTokenStore()
        // D-4: the Keychain outlives app deletion, the installation id does not.
        _ = InstallationID.current(defaults: defaults, onFirstStart: store.clearAll)
        return assemble(client: client, store: store, opener: SystemURLOpener(), tokens: ApnsTokenProvider.shared)
    }

    /// Wires the clients on one transport and one token store. The stub backend uses the same wiring.
    @MainActor
    static func assemble(
        client: APIClient, store: any TokenStore, opener: any URLOpener, tokens: any TokenProvider
    ) -> AdminEnvironment {
        let session = SessionManager(client: client, store: store)
        return AdminEnvironment(
            session: session,
            auth: HTTPAuthService(
                client: client, session: session,
                installationID: InstallationID.current(), deviceName: InstallationID.deviceName()
            ),
            orders: HTTPOrdersAPI(client: client, session: session),
            account: HTTPAccountAPI(client: client, session: session),
            owner: HTTPOwnerAPI(client: client, session: session),
            baseURL: client.baseURL,
            push: PushRegistrar(provider: tokens, api: HTTPPushAPI(client: client, session: session)),
            router: NotificationRouter.shared,
            opener: opener
        )
    }
}
