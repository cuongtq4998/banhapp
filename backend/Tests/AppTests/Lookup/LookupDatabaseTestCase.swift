import XCTVapor
import FluentSQL
@testable import App

/// The lookup route over a real PostgreSQL (skipped without a database URL).
class LookupDatabaseTestCase: AdminOrderTestCase {
    /// Random per test: orders of other runs share the database.
    let customer = "+8490" + String(Int.random(in: 1_000_000...9_999_999))
    var policy = LookupPolicy()

    /// Applies `policy` to the running app; call after changing it.
    func applyPolicy() {
        policy.floorMilliseconds = 0
        app.services.lookup = policy
        app.services.lookupGuard = LookupGuard(policy: policy)
    }

    func seed(_ build: (inout SeedOrder) -> Void = { _ in }) async throws -> String {
        var order = SeedOrder()
        order.phone = customer
        build(&order)
        return try await place(order)
    }

    /// Moves the status time without a status change, so the trigger stays out.
    func setStatusAge(_ orderCode: String, secondsAgo: TimeInterval) async throws {
        let at = clock.now().addingTimeInterval(-secondsAgo)
        try await run("UPDATE customer_order SET status_changed_at = \(timestamp(at)) WHERE order_code = \(bind: orderCode)")
    }

    func lookup(cursor: String? = nil, headers: HTTPHeaders = [:]) async throws -> Reply {
        let cursorPart = cursor.map { #","cursor":"\#($0)""# } ?? ""
        var all: HTTPHeaders = ["Content-Type": "application/json"]
        headers.forEach { all.replaceOrAdd(name: $0.name, value: $0.value) }
        let box = LockedBox<Reply?>(nil)
        try await app.test(.POST, "v1/orders/lookup", headers: all, body: ByteBuffer(string: #"{"phone":"\#(customer)"\#(cursorPart)}"#)) { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        }
        return try XCTUnwrap(box.value)
    }

    func lookedUp(_ reply: Reply) -> [String] {
        (reply.json["orders"] as? [[String: Any]] ?? []).compactMap { $0["order_code"] as? String }
    }

    func nextCursor(_ reply: Reply) -> String? { reply.json["next_cursor"] as? String }

    func expectLookup(_ codes: [String], file: StaticString = #filePath, line: UInt = #line) async throws {
        let reply = try await lookup()
        XCTAssertEqual(lookedUp(reply), codes, file: file, line: line)
    }
}
