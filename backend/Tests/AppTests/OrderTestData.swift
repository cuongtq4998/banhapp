import Foundation
import BanhContracts
@testable import App

/// Ids, rules and requests that reproduce the shared order fixtures
/// (`contracts/fixtures/order-*.json`). Fake data only.
enum OrderTestData {
    static let productID = UUID(uuidString: "0b8f1f0e-1111-4a00-8000-000000000001")!
    static let inactiveProductID = UUID(uuidString: "0b8f1f0e-1111-4a00-8000-000000000002")!
    static let districtID = UUID(uuidString: "0b8f1f0e-2222-4a00-8000-000000000001")!
    static let slotID = UUID(uuidString: "0b8f1f0e-3333-4a00-8000-000000000001")!
    static let idempotencyKey = UUID(uuidString: "5e0c2f6a-4c47-4a0e-9b6e-0f3a5d9c1a10")!
    static let keyText = "5e0c2f6a-4c47-4a0e-9b6e-0f3a5d9c1a10"
    static let phone = "+84900000000"
    static let placed = PlacedOrder(orderCode: "BT-7K3M9Q", createdAt: "2026-11-02T05:00:00Z")

    /// Today is 2026-11-02 (shop time), lead 2, horizon 30, daily limit 100, minimum 2 cakes.
    static let rules = AvailabilityRules(leadDays: 2, maxDaysAhead: 30, dailyLimit: 100, activeProductCount: 2, maxQtyPerCake: 99)

    static let referenceData = OrderReferenceData(
        rules: rules, minQty: 2,
        products: [
            productID: OrderProductRecord(id: productID, name: "Bánh chuối", priceVND: 50_000, isActive: true),
            inactiveProductID: OrderProductRecord(id: inactiveProductID, name: "Bánh ẩn", priceVND: 45_000, isActive: false)
        ],
        slot: OrderSlotRecord(id: slotID, startTime: "08:00:00", endTime: "10:00:00", isActive: true),
        district: OrderDistrictRecord(id: districtID, name: "Quận 1", deliveryFeeVND: 20_000, isActive: true)
    )

    static let request = OrderRequest(
        items: [.init(productID: productID, quantity: 2)],
        deliveryDate: BusinessDate(year: 2026, month: 11, day: 5), slotID: slotID,
        customerName: "Nguyễn Văn A", customerPhone: phone, customerAddress: "1 Đường Số 5",
        districtID: districtID, note: nil, expectedTotalVND: 120_000
    )

    static func command(_ request: OrderRequest = request, key: UUID = idempotencyKey) -> OrderCommand {
        OrderCommand(shopID: AppConfig.testShopID, request: request, idempotencyKey: key, platform: "ios", appVersion: "1.0.0")
    }

    static func service(_ repository: any OrderRepository, maxPerPhone: Int = 5, codes: any OrderCodeGenerator = FixedCodes(["BT-7K3M9Q"])) -> OrderPlacementService {
        OrderPlacementService(
            repository: repository, calendar: ShopCalendar(clock: AvailabilityTestData.clock),
            orderCodes: codes, maxOrdersPerPhonePerDay: maxPerPhone
        )
    }

    static func fixtureBody(_ name: String = "order-request.json") throws -> Data {
        try Data(contentsOf: TestPaths.contractFixtures.appendingPathComponent(name))
    }

    static func json(_ data: Data) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: data) }
}

/// Hands out the given codes in order, repeating the last one.
final class FixedCodes: OrderCodeGenerator {
    private let codes: [String]
    private let next = LockedBox(0)
    init(_ codes: [String]) { self.codes = codes }
    func makeCode() -> String {
        let index = next.value
        next.set(index + 1)
        return codes[min(index, codes.count - 1)]
    }
}

/// In-memory order repository. Records the calls so tests can check the
/// order of the steps and that nothing was written.
final class FakeOrderRepository: OrderRepository {
    struct State {
        var data: OrderReferenceData
        var stored: [UUID: StoredOrder] = [:]
        var outcomes: [OrderInsertOutcome] = []
        var phoneCount = 0
        var calls: [String] = []
        var inserted: [NewOrder] = []
        var failure: (any Error)?
    }
    private let state: LockedBox<State>

    init(data: OrderReferenceData = OrderTestData.referenceData) { state = LockedBox(State(data: data)) }

    func update(_ change: (inout State) -> Void) { var copy = state.value; change(&copy); state.set(copy) }
    var calls: [String] { state.value.calls }
    var inserted: [NewOrder] { state.value.inserted }

    private func record(_ call: String) throws {
        update { $0.calls.append(call) }
        if let failure = state.value.failure { throw failure }
    }

    func loadReferenceData(shopID: UUID, productIDs: [UUID], slotID: UUID, districtID: UUID) async throws -> OrderReferenceData {
        try record("load")
        return state.value.data
    }

    func findOrder(shopID: UUID, idempotencyKey: UUID) async throws -> StoredOrder? {
        try record("find")
        return state.value.stored[idempotencyKey]
    }

    func countOrders(shopID: UUID, phone: String, since: Date) async throws -> Int {
        try record("count")
        return state.value.phoneCount
    }

    func insertOrder(_ order: NewOrder) async throws -> OrderInsertOutcome {
        try record("insert")
        update { $0.inserted.append(order) }
        if !state.value.outcomes.isEmpty {
            var outcome = OrderInsertOutcome.capacityExceeded
            update { outcome = $0.outcomes.removeFirst() }
            return outcome
        }
        let placed = PlacedOrder(orderCode: order.orderCode, createdAt: OrderTestData.placed.createdAt)
        update { $0.stored[order.idempotencyKey] = StoredOrder(placed: placed, requestHash: order.requestHash) }
        return .created(placed)
    }
}

/// A status-and-headers fixture (`order-created.json`, `order-replay.json`).
struct OrderExchange: Decodable {
    let status: Int
    let responseHeaders: [String: String]
    let body: OrderCreatedResponse

    static func load(_ name: String) throws -> OrderExchange {
        try JSONDecoder().decode(OrderExchange.self, from: OrderTestData.fixtureBody(name))
    }

    private enum CodingKeys: String, CodingKey {
        case status, body
        case responseHeaders = "response_headers"
    }
}
