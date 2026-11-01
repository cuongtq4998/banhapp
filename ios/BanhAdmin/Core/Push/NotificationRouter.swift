import UIKit
import UserNotifications

/// A notification the person tapped or that arrived while the app is open.
enum NotificationEvent: Equatable {
    case tapped(orderCode: String)
    case foreground(orderCode: String)
}

/// Hands notification events to the coordinator. An event that arrives before the coordinator listens
/// (the app was closed) is kept and delivered when it starts to listen. In memory only.
@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()
    private var queued: [NotificationEvent] = []
    private var handler: ((NotificationEvent) -> Void)?

    func listen(_ handler: @escaping (NotificationEvent) -> Void) {
        self.handler = handler
        let waiting = queued
        queued.removeAll()
        waiting.forEach(handler)
    }

    func deliver(_ event: NotificationEvent) {
        if let handler { handler(event) } else { queued.append(event) }
    }

    /// `order_code` of the payload (api/06 10.12); nothing else of the payload is used.
    static func orderCode(from userInfo: [AnyHashable: Any]) -> String? {
        (userInfo["order_code"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in ApnsTokenProvider.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Task { @MainActor in ApnsTokenProvider.shared.didFail() }
    }

    /// Foreground: no system banner; the app shows its own toast (A_NOTIF_FOREGROUND).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        await MainActor.run {
            if let code = NotificationRouter.orderCode(from: info) { NotificationRouter.shared.deliver(.foreground(orderCode: code)) }
        }
        return []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        await MainActor.run {
            if let code = NotificationRouter.orderCode(from: info) { NotificationRouter.shared.deliver(.tapped(orderCode: code)) }
        }
    }
}
