import UIKit
import UserNotifications

/// Gives the device push token, asking for the notification permission when `prompt` is true and the
/// person has not been asked yet (the system shows its request once). nil: no permission or no token.
@MainActor
protocol TokenProvider {
    func token(prompt: Bool) async -> String?
    /// Sign-out: stop receiving pushes on this phone (the server also clears its copy).
    func unregister()
}

/// The real APNs path. UNVERIFIED on a device: simulators cannot obtain a token, and no Apple team or
/// key exists in this repository (see dev-guide).
@MainActor
final class ApnsTokenProvider: TokenProvider {
    static let shared = ApnsTokenProvider()
    private var waiting: CheckedContinuation<String?, Never>?

    func token(prompt: Bool) async -> String? {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined, prompt {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional || status == .ephemeral else { return nil }
        return await withCheckedContinuation { continuation in
            waiting?.resume(returning: nil)
            waiting = continuation
            UIApplication.shared.registerForRemoteNotifications()
            // No answer (simulator, no network, missing entitlement): give up after 15 s.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                self?.finish(nil)
            }
        }
    }

    func unregister() { UIApplication.shared.unregisterForRemoteNotifications() }

    func didRegister(deviceToken: Data) { finish(deviceToken.map { String(format: "%02x", $0) }.joined()) }
    func didFail() { finish(nil) }

    private func finish(_ token: String?) {
        waiting?.resume(returning: token)
        waiting = nil
    }
}

#if DEBUG
/// Debug and UI-test provider: a fixed fake token, no permission request, nothing leaves the phone.
@MainActor
final class FakeTokenProvider: TokenProvider {
    private(set) var prompts = 0
    private(set) var unregisterCount = 0
    var result: String? = "fake-token-0001"

    func token(prompt: Bool) async -> String? {
        if prompt { prompts += 1 }
        return result
    }

    func unregister() { unregisterCount += 1 }
}
#endif
