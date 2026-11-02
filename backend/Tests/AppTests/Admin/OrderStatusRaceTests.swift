import XCTVapor
@testable import App

/// Two devices at once. The database serialises the writers on
/// the row, so exactly one change is made and the cakes return at most once.
final class OrderStatusRaceTests: AdminOrderTestCase {
    private func race(_ requests: [(Phone, String)], on orderCode: String) async throws -> [Reply] {
        let app = try XCTUnwrap(self.app)
        return try await withThrowingTaskGroup(of: Reply.self) { group in
            for (phone, body) in requests { group.addTask { try await Self.change(app, phone, orderCode, body) } }
            var replies: [Reply] = []
            for try await reply in group { replies.append(reply) }
            return replies
        }
    }

    func testProcessAgainstCancelHasOneWinner() async throws {
        let a = try await phone(.staff, "Nhan Vien A"), b = try await phone(.staff, "Nhan Vien B")
        for round in 0..<8 {
            let date = day(5 + round)
            let orderCode = try await place(.init(date: date, cakes: 3))
            let replies = try await race([(a, move("Received", "Processing")), (b, move("Received", "Cancelled", reason: "customer_asked"))], on: orderCode)
            XCTAssertEqual(replies.filter { $0.status == .ok }.count, 1, "round \(round)")
            XCTAssertEqual(replies.filter { $0.errorCode == "ORDER_STATE_CHANGED" }.count, 1, "round \(round)")
            let eventCount = try await events(of: orderCode)
            XCTAssertEqual(eventCount, 1)
            let stored = try await status(of: orderCode)
            let load = try await loaded(date)
            XCTAssertEqual(load, stored == "Cancelled" ? 0 : 3, "capacity is released only when the cancel won")
        }
    }

    func testTwoPeopleCancellingOneOrderReleaseTheCakesOnce() async throws {
        let a = try await phone(.staff, "Nhan Vien A"), b = try await phone(.staff, "Nhan Vien B")
        let orderCode = try await place(.init(date: day(5), cakes: 4))
        try await addLoad(day(5), 6)
        let body = move("Received", "Cancelled", reason: "cannot_deliver")
        let replies = try await race([(a, body), (b, body)], on: orderCode)
        XCTAssertEqual(replies.filter { $0.status == .ok }.count, 1)
        XCTAssertEqual(replies.filter { $0.status == .conflict }.count, 1)
        let load = try await loaded(day(5))
        XCTAssertEqual(load, 6)
        let eventCount = try await events(of: orderCode)
        XCTAssertEqual(eventCount, 1)
    }

    func testADoubleTapFromOnePhoneChangesOnceAndBothAnswerOk() async throws {
        let a = try await phone(.staff, "Nhan Vien A")
        for round in 0..<5 {
            let orderCode = try await place(.init(date: day(5 + round), cakes: 2))
            let body = move("Received", "Cancelled", reason: "customer_asked")
            let replies = try await race([(a, body), (a, body), (a, body)], on: orderCode)
            XCTAssertEqual(replies.map(\.status), [.ok, .ok, .ok])
            XCTAssertEqual(replies.filter { $0.headers.first(name: "Idempotent-Replay") == "true" }.count, 2)
            let eventCount = try await events(of: orderCode)
            XCTAssertEqual(eventCount, 1)
            let load = try await loaded(day(5 + round))
            XCTAssertEqual(load, 0)
        }
    }
}
