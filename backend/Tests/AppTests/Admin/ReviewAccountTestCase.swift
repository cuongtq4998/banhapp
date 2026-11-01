import XCTVapor
import FluentSQL
@testable import App

/// Setup of the store-review account tests (ADR-0027): the account is on in the
/// server configuration with a fake address and a fake fixed code.
class ReviewAccountTestCase: AdminOrderTestCase {
    let reviewEmail = "review.demo.\(UUID().uuidString.prefix(8).lowercased())@example.com"
    let fixedCode = "246810"
    override var reviewConfig: ReviewAccountConfig? { ReviewAccountConfig(email: reviewEmail, code: fixedCode) }

    /// What `review-account on` does, against the test shop.
    func switchOn() async throws {
        try await ReviewAccountCommand.enable(on: app.db, shopID: shopID, review: ReviewAccountConfig(email: reviewEmail, code: fixedCode), clock: clock)
    }

    func switchOff() async throws {
        try await ReviewAccountCommand.disable(on: app.db, shopID: shopID)
    }

    /// Request a code for the review address and enter the fixed code.
    func reviewSignIn(code: String? = nil, installation: UUID = UUID()) async throws -> Reply {
        let requested = try await requestCode(reviewEmail)
        XCTAssertEqual(requested.status, .accepted)
        await app.services.background.drain()
        let reply = try await signIn(reviewEmail, code ?? fixedCode, installation: installation)
        clock.advance(31)
        return reply
    }

    func reviewPhone() async throws -> Phone {
        let reply = try await reviewSignIn()
        XCTAssertEqual(reply.status, .created, String(decoding: reply.data, as: UTF8.self))
        return Phone(installationID: UUID(), access: reply.string("access_token"), refresh: reply.string("refresh_token"),
                     deviceID: UUID(uuidString: reply.string("device_id")) ?? UUID())
    }

    func demoCodes() async throws -> [String] {
        let rows = try await sql.raw("SELECT order_code FROM customer_order WHERE shop_id = \(bind: shopID) AND is_demo ORDER BY order_code").all()
        return try rows.map { try $0.decode(column: "order_code", as: String.self) }
    }
}
