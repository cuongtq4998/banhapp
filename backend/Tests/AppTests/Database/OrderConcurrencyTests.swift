import XCTVapor
import FluentSQL
@testable import App

/// AC-22 and AC-19 under real parallel connections (ADR-0008).
final class OrderConcurrencyTests: OrderDatabaseTestCase {
    private func sendAll(_ jobs: [(Data, UUID)]) async throws -> [Answer] {
        let app = try XCTUnwrap(self.app)
        return try await withThrowingTaskGroup(of: Answer.self) { group in
            for (payload, key) in jobs { group.addTask { try await Self.send(app, payload, key: key) } }
            return try await group.reduce(into: []) { $0.append($1) }
        }
    }

    func testParallelOrdersNeverOversellTheDate() async throws {
        let seed = try await start(dailyLimit: 10)
        let jobs = try (0..<24).map { index in
            (try body(seed, phone: String(format: "09000001%02d", index)), UUID())
        }
        let answers = try await sendAll(jobs)
        let created = answers.filter { $0.status == .created }.count
        let full = answers.filter { $0.status == .conflict && (try? errorCode($0)) == "DATE_CAPACITY" }.count
        XCTAssertEqual(created, 5)
        XCTAssertEqual(full, 19)
        let counter = try await cakes(seed)
        let stored = try await count("SELECT coalesce(sum(total_cakes), 0)::int AS n FROM customer_order WHERE shop_id = \(bind: seed.shopID) AND status <> 'Cancelled'")
        let orders = try await orderCount(seed)
        XCTAssertEqual(counter, 10)
        XCTAssertEqual(stored, 10)
        XCTAssertEqual(orders, 5)
        let codes = try await count("SELECT count(DISTINCT order_code)::int AS n FROM customer_order WHERE shop_id = \(bind: seed.shopID)")
        XCTAssertEqual(codes, 5)
    }

    func testTwoRacersForTheLastCakesLeaveExactlyOneOrder() async throws {
        let seed = try await start(dailyLimit: 2)
        let answers = try await sendAll([
            (try body(seed, phone: "0900000011"), UUID()), (try body(seed, phone: "0900000012"), UUID())
        ])
        XCTAssertEqual(answers.map(\.status).sorted { $0.code < $1.code }, [.created, .conflict])
        let orders = try await orderCount(seed)
        XCTAssertEqual(orders, 1)
    }

    func testParallelRetriesOfOneKeyCreateOneOrder() async throws {
        let seed = try await start(dailyLimit: 20)
        let key = UUID()
        let payload = try body(seed)
        let answers = try await sendAll(Array(repeating: (payload, key), count: 10))
        XCTAssertEqual(answers.filter { $0.status == .created }.count, 1)
        XCTAssertEqual(answers.filter { $0.status == .ok && $0.replayHeader == "true" }.count, 9)
        XCTAssertEqual(Set(answers.map(\.body)).count, 1, "\(Set(answers.map(\.body)))")
        let orders = try await orderCount(seed)
        let counter = try await cakes(seed)
        XCTAssertEqual(orders, 1)
        XCTAssertEqual(counter, 2)
    }

    func testParallelRetriesOfOneKeyOnTheLastCakesNeverAnswerFull() async throws {
        let seed = try await start(dailyLimit: 2)
        let key = UUID()
        let payload = try body(seed)
        let answers = try await sendAll(Array(repeating: (payload, key), count: 8))
        XCTAssertEqual(answers.filter { $0.status == .created }.count, 1)
        XCTAssertTrue(answers.allSatisfy { $0.status == .created || $0.status == .ok }, "\(answers.map(\.status))")
        let orders = try await orderCount(seed)
        XCTAssertEqual(orders, 1)
    }
}
