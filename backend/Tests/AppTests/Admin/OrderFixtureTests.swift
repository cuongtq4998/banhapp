import XCTVapor
import BanhContracts
@testable import App

/// The shared fixtures of the order endpoints (`contracts/fixtures/admin/`)
/// against the real answers: same keys and value kinds, same error envelopes.
final class OrderFixtureTests: AdminOrderTestCase {
    private func shape(_ reply: Reply) -> NSDictionary { AdminFixtures.shape(reply.json) as? NSDictionary ?? [:] }

    private func envelope(_ reply: Reply) throws -> APIErrorResponse.Body {
        try JSONDecoder().decode(APIErrorResponse.self, from: reply.data).error
    }

    func testListDetailAndChangeHaveTheFixtureShape() async throws {
        let orderCode = try await place(.init(date: day(0)))
        let staff = try await phone(.staff, "Nhan Vien A")
        let listed = try await list(staff)
        XCTAssertEqual(shape(listed), try AdminFixtures.bodyShape("orders-list"))
        let row = AdminFixtures.shape((listed.json["items"] as? [Any])?.first ?? [:]) as? NSDictionary
        let fixtureItems = (try JSONSerialization.jsonObject(with: AdminFixtures.load("orders-list")) as? [String: Any])?["body"] as? [String: Any]
        XCTAssertEqual(row, AdminFixtures.shape((fixtureItems?["items"] as? [Any])?.first ?? [:]) as? NSDictionary)
        let opened = try await detail(staff, orderCode)
        XCTAssertEqual(shape(opened), try AdminFixtures.bodyShape("order-detail"))
        let changed = try await change(staff, orderCode, move("Received", "Cancelled", reason: "customer_asked"))
        XCTAssertEqual(shape(changed), try AdminFixtures.bodyShape("order-status-change"))
    }

    func testErrorsMatchTheFixtures() async throws {
        let orderCode = try await place()
        let staff = try await phone(.staff, "Nhan Vien A"), other = try await phone(.staff, "Nhan Vien B")
        let missing = try await detail(staff, code(99_999_999))
        XCTAssertEqual(try envelope(missing), try AdminFixtures.error("order-not-found"))
        let invalid = try await change(staff, orderCode, move("Received", "Finished"))
        XCTAssertEqual(try envelope(invalid), try AdminFixtures.error("status-transition-invalid"))
        let noReason = try await change(staff, orderCode, move("Received", "Cancelled"))
        XCTAssertEqual(try envelope(noReason), try AdminFixtures.error("cancel-reason-required"))
        _ = try await change(staff, orderCode, move("Received", "Processing"))
        let stale = try await change(other, orderCode, move("Received", "Cancelled", reason: "fake_spam"))
        let actual = try envelope(stale), fixture = try AdminFixtures.error("order-state-changed")
        XCTAssertEqual(actual.code, fixture.code)
        XCTAssertEqual(actual.messageKey, fixture.messageKey)
        let order = try XCTUnwrap(stale.json["error"] as? [String: Any])["details"] as? [String: Any]
        let fixtureOrder = try XCTUnwrap(JSONSerialization.jsonObject(with: AdminFixtures.load("error-order-state-changed")) as? [String: Any])
        let expected = ((fixtureOrder["error"] as? [String: Any])?["details"] as? [String: Any])?["order"]
        XCTAssertEqual(AdminFixtures.shape(order?["order"] ?? [:]) as? NSDictionary, AdminFixtures.shape(expected ?? [:]) as? NSDictionary)
    }
}
