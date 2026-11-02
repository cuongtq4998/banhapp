import XCTVapor
@testable import App

/// Page cap of api/10: 5 pages, and the last one has no next cursor.
final class LookupPagingTests: LookupRouteTestCase {
    private func walk(rows: Int) async throws -> (pages: Int, orders: Int, lastCursor: Any?) {
        store.plant(normalised, (1...rows).map { .sample($0) })
        var cursor: String?
        var pages = 0, orders = 0
        var lastCursor: Any?
        repeat {
            let cursorField = cursor.map { #","cursor":"\#($0)""# } ?? ""
            try await lookup(#"{"phone":"\#(phone)"\#(cursorField)}"#) { res in
                XCTAssertEqual(res.status, .ok)
                let answer = try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any]
                orders += (answer?["orders"] as? [Any])?.count ?? 0
                lastCursor = answer?["next_cursor"]
                cursor = answer?["next_cursor"] as? String
            }
            pages += 1
        } while cursor != nil && pages < 20
        return (pages, orders, lastCursor)
    }

    private func policy() -> LookupPolicy {
        var policy = LookupPolicy()
        policy.floorMilliseconds = 0
        policy.perPhonePerHour = 100
        policy.perAddressPerHour = 100
        return policy
    }

    func testFiftyOrdersInFivePagesAtDefaultSize() async throws {
        try await start(policy: policy())
        let result = try await walk(rows: LookupPolicy.Default.pageSize * LookupPolicy.Default.maxPages + 15)
        XCTAssertEqual(result.pages, LookupPolicy.Default.maxPages)
        XCTAssertEqual(result.orders, LookupPolicy.Default.pageSize * LookupPolicy.Default.maxPages)
        XCTAssertTrue(result.lastCursor is NSNull, "page 5 never offers page 6")
    }

    func testSmallInjectedPageSizeStillStopsAtFivePages() async throws {
        var tuned = policy()
        tuned.pageSize = 2
        try await start(policy: tuned)
        let result = try await walk(rows: 30)
        XCTAssertEqual(result.pages, tuned.maxPages)
        XCTAssertEqual(result.orders, tuned.pageSize * tuned.maxPages)
    }

    func testShortListEndsBeforeTheCap() async throws {
        try await start(policy: policy())
        let result = try await walk(rows: 12)
        XCTAssertEqual(result.pages, 2)
        XCTAssertEqual(result.orders, 12)
    }
}
