import Foundation
import Crypto

/// Settings of push to phones (ADR-0024). Without `PUSH_PROVIDER` push is off
/// and orders are stored as before. `live` needs the whole APNs set and the
/// whole FCM set, and a key that parses; a half-set configuration stops the
/// start, like the mail setup.
struct PushConfig: Equatable, Sendable {
    enum Provider: String, Sendable {
        case off
        /// Keeps the pushes in memory (tests); refused in production.
        case recording
        case live
    }

    struct Apns: Equatable, Sendable {
        let keyID: String
        let teamID: String
        /// PEM text of the `.p8` key.
        let privateKey: String
        /// The admin app's bundle id.
        let topic: String
    }

    struct Fcm: Equatable, Sendable {
        let projectID: String
        let serviceAccountJSON: String
    }

    static let off = PushConfig(provider: .off, apns: nil, fcm: nil)

    let provider: Provider
    let apns: Apns?
    let fcm: Fcm?

    init(provider: Provider, apns: Apns?, fcm: Fcm?) {
        self.provider = provider
        self.apns = apns
        self.fcm = fcm
    }

    init(environment: EnvironmentVariables, stage: AppConfig.Stage) throws {
        typealias Key = AppConfig.Key
        let names = [Key.apnsKeyID, Key.apnsTeamID, Key.apnsPrivateKey, Key.apnsTopic, Key.fcmProjectID, Key.fcmServiceAccountJSON]
        let anyCredential = names.contains { environment.value($0) != nil }
        guard let text = environment.value(Key.pushProvider) else {
            // Credentials without a switch are a forgotten line, not "off".
            if anyCredential { throw AppConfig.Failure.missing(Key.pushProvider) }
            self = .off
            return
        }
        guard let provider = Provider(rawValue: text), !(provider == .recording && stage == .production) else {
            throw AppConfig.Failure.invalid(Key.pushProvider)
        }
        guard provider == .live else {
            self.init(provider: provider, apns: nil, fcm: nil)
            return
        }
        func required(_ key: String) throws -> String {
            guard let value = environment.value(key) else { throw AppConfig.Failure.missing(key) }
            return value
        }
        let apns = Apns(
            keyID: try required(Key.apnsKeyID), teamID: try required(Key.apnsTeamID),
            privateKey: Self.restoringLineBreaks(try required(Key.apnsPrivateKey)), topic: try required(Key.apnsTopic)
        )
        let fcm = Fcm(projectID: try required(Key.fcmProjectID), serviceAccountJSON: try required(Key.fcmServiceAccountJSON))
        guard (try? P256.Signing.PrivateKey(pemRepresentation: apns.privateKey)) != nil else {
            throw AppConfig.Failure.invalid(Key.apnsPrivateKey)
        }
        guard (try? FcmServiceAccount.parse(fcm.serviceAccountJSON)) != nil else {
            throw AppConfig.Failure.invalid(Key.fcmServiceAccountJSON)
        }
        self.init(provider: .live, apns: apns, fcm: fcm)
    }

    /// A key pasted into a one-line variable carries `\n` as two characters.
    static func restoringLineBreaks(_ text: String) -> String {
        text.replacingOccurrences(of: "\\n", with: "\n")
    }
}
