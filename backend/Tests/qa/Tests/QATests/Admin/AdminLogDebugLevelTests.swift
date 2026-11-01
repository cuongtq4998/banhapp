import XCTest
import Vapor
@testable import AppUnderTest

/// Exploratory: what the log holds when an operator sets LOG_LEVEL=debug. The contract (BR-7) is about the
/// default level; this test asserts the secrets stay out at debug and prints what personal data a lower level exposes.
final class AdminLogDebugLevelTests: AdminQABase {
    // At .trace SwiftNIO logs every decoded request head, Authorization header and query included (observation O-3).
    override var logLevel: Logger.Level { .debug }

    func testTCB96c_DebugLevelLogDoesNotHoldSecrets() async throws {
        try await aeq(try await requestCode(ownerEmail).status, 202)
        let code = try XCTUnwrap(mail.lastCode(to: ownerEmail))
        let reply = try await signInReply(ownerEmail, code: code)
        let access = reply.string("access_token"), refresh = reply.string("refresh_token")
        _ = try await seedOrder(date: dayOffset(4), phone: "+84900000098", name: "Le Thi Debug")
        _ = try await client.send("GET", "v1/admin/orders?q=Debug", token: access)
        _ = try await client.send("POST", "v1/auth/refresh", json: ["refresh_token": refresh])
        let log = logs.lines.map { "\($0.message) \($0.metadata)" }.joined(separator: "\n")
        var findings: [String] = []
        for (label, needle) in [("access token", access), ("refresh token", refresh), ("sign-in code", code), ("pepper", pepper), ("e-mail address", ownerEmail),
                                ("customer name", "Le Thi Debug"), ("customer phone", "+84900000098")] where log.contains(needle) { findings.append(label) }
        print("QA-OBSERVATION debug-level log exposes: \(findings.isEmpty ? "nothing" : findings.joined(separator: ", "))")
        for secret in ["access token", "refresh token", "sign-in code", "pepper"] {
            XCTAssertFalse(findings.contains(secret), "debug log holds the \(secret)")
        }
    }
}
