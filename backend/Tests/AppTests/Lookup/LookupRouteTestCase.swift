import XCTVapor
@testable import App

/// In-memory store: records what was asked, answers what the test planted.
final class FakeLookupStore: LookupStore, @unchecked Sendable {
    private let lock = NSLock()
    private var rows: [String: [LookupRow]] = [:]
    private(set) var calls = 0
    private(set) var lastWindowStart: Date?

    func plant(_ phone: String, _ list: [LookupRow]) { lock.withLock { rows[phone] = list } }

    func fetchPage(phone: String, cursor: LookupCursor?, windowStart: Date, limit: Int) async throws -> [LookupRow] {
        lock.withLock {
            calls += 1
            lastWindowStart = windowStart
            let all = (rows[phone] ?? []).sorted { ($0.created_at, $0.id.uuidString) > ($1.created_at, $1.id.uuidString) }
            let after = all.filter { row in cursor.map { (row.created_at, row.id.uuidString) < ($0.placedAt, $0.orderID.uuidString) } ?? true }
            return Array(after.prefix(limit))
        }
    }
}

extension LookupRow {
    static func sample(_ n: Int, at date: Date = AvailabilityTestData.clock.now()) -> LookupRow {
        LookupRow(
            id: UUID(), order_code: "BT-AAAAA\(n % 10)", status: "Received", created_at: date.addingTimeInterval(TimeInterval(-n)),
            district_name: "District 1", requested: "2026-11-05", slot_start: "14:00", slot_end: "16:00", expected: nil,
            items_subtotal_vnd: 240_000, delivery_fee_vnd: 20_000, delivery_fee_final_vnd: nil,
            items: [.init(cakeName: "Plain cake", quantity: 2, unitPriceVnd: 120_000)]
        )
    }
}

class LookupRouteTestCase: XCTestCase {
    var app: Application!
    let store = FakeLookupStore()
    let capture = LogCapture()
    let phone = "0900000001"
    let normalised = "+84900000001"

    func start(policy: LookupPolicy? = nil) async throws {
        app = try await Application.make(.testing)
        app.logger = capture.makeLogger()
        try await configure(app, config: .localWithShop())
        app.services.clock = AvailabilityTestData.clock
        var tuned = policy ?? LookupPolicy()
        if policy == nil { tuned.floorMilliseconds = 0 }
        app.services.lookup = tuned
        app.services.lookupGuard = LookupGuard(policy: tuned)
        let fake = store
        app.services.makeLookupStore = { _ in fake }
    }

    override func tearDown() async throws { try await app?.asyncShutdown() }

    func lookup(_ json: String, headers: HTTPHeaders = ["Content-Type": "application/json"], _ check: @escaping (XCTHTTPResponse) async throws -> Void) async throws {
        try await app.test(.POST, "v1/orders/lookup", headers: headers, body: ByteBuffer(string: json), afterResponse: { res async throws in try await check(res) })
    }

    func keys(_ res: XCTHTTPResponse) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any]
        let order = (object?["orders"] as? [[String: Any]])?.first ?? [:]
        return Set(order.keys)
    }
}
