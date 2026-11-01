import Foundation

/// Routes a push to the service of the phone's platform.
struct LivePushSender: PushSender {
    let apns: ApnsPushSender
    let fcm: FcmPushSender

    func send(_ message: PushMessage, to target: PushTarget) async throws -> PushOutcome {
        switch target.platform {
        case .ios: return try await apns.send(message, to: target)
        case .android: return try await fcm.send(message, to: target)
        }
    }
}
