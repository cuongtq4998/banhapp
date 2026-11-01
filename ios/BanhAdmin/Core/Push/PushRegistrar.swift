import Foundation

/// Sends the device token to the server (FR-25). Failures are silent: every function works without
/// push, and the next launch tries again.
@MainActor
final class PushRegistrar {
    private let provider: any TokenProvider
    private let api: any PushAPI
    private let environment: String
    private(set) var lastSent: String?

    /// `sandbox` for debug builds (development entitlement), `production` for release builds.
    nonisolated static var currentEnvironment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    init(provider: any TokenProvider, api: any PushAPI, environment: String = PushRegistrar.currentEnvironment) {
        self.provider = provider
        self.api = api
        self.environment = environment
    }

    /// `prompt`: right after the first successful sign-in on this phone. Later launches pass false and
    /// only refresh the token when the permission is already granted. A denied permission sends nothing.
    func register(prompt: Bool) async {
        guard let token = await provider.token(prompt: prompt), !token.isEmpty else { return }
        do {
            try await api.register(token: token, environment: environment)
            lastSent = token
        } catch {}
    }

    /// Sign-out and ended sessions: forget the token here; the server clears its copy with the session.
    func unregister() {
        lastSent = nil
        provider.unregister()
    }
}
