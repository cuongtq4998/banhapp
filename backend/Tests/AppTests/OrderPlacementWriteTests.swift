import XCTest
import BanhContracts
@testable import App

/// The last two steps of api.md 4.3: the per-phone limit and the insert with
/// its lost races.
final class OrderPlacementWriteTests: XCTestCase {
    typealias Data = OrderTestData

    private func failure(_ repository: FakeOrderRepository, service: OrderPlacementService? = nil) async -> APIError? {
        do {
            _ = try await (service ?? Data.service(repository)).place(Data.command())
            return nil
        } catch { return error as? APIError }
    }

    func testPhoneLimitStopsTheFifthOrderOfADay() async throws {
        let repository = FakeOrderRepository()
        repository.update { $0.phoneCount = 4 }
        _ = try await Data.service(repository).place(Data.command())
        repository.update { $0.phoneCount = 5; $0.stored = [:] }
        let error = await failure(repository)
        XCTAssertEqual(error?.code, .rateLimited)
        XCTAssertEqual(error?.retryAfterSeconds, APIError.maxRetryAfterSeconds)
        XCTAssertEqual(repository.inserted.count, 1)
    }

    func testPhoneLimitComesAfterThePriceCheckAndBeforeCapacity() async {
        let repository = FakeOrderRepository()
        repository.update { $0.phoneCount = 5 }
        let wrongPrice = Data.request.replacing(expected: 1)
        do {
            _ = try await Data.service(repository).place(Data.command(wrongPrice))
            XCTFail("expected an error")
        } catch { XCTAssertEqual((error as? APIError)?.code, .priceChanged) }
        let limited = await failure(repository)
        XCTAssertEqual(limited?.code, .rateLimited)
        XCTAssertEqual(repository.calls.filter { $0 == "insert" }.count, 0)
    }

    func testReplayIsNotCountedAgainstThePhoneLimit() async throws {
        let repository = FakeOrderRepository()
        let service = Data.service(repository)
        _ = try await service.place(Data.command())
        repository.update { $0.phoneCount = 5 }
        let replay = try await service.place(Data.command())
        XCTAssertEqual(replay, .replayed(Data.placed))
    }

    func testFullDateAnswersCapacityWithTheDate() async {
        let repository = FakeOrderRepository()
        repository.update { $0.outcomes = [.capacityExceeded] }
        let error = await failure(repository)
        XCTAssertEqual(error?.code, .dateCapacity)
        XCTAssertEqual(error?.details, ["delivery_date": .string("2026-11-05")])
    }

    func testLostCapacityRaceOfTheSameKeyReplaysTheWinner() async throws {
        let repository = FakeOrderRepository()
        repository.update {
            $0.outcomes = [.capacityExceeded]
            $0.stored[Data.idempotencyKey] = nil
        }
        // The winner appears between the first lookup and the failed insert.
        let winner = StoredOrder(placed: Data.placed, requestHash: OrderRequestHash.make(Data.request))
        let racing = RacingRepository(base: repository, winner: winner, key: Data.idempotencyKey)
        let result = try await Data.service(racing).place(Data.command())
        XCTAssertEqual(result, .replayed(Data.placed))
    }

    func testDuplicateKeyReadsTheWinner() async throws {
        let repository = FakeOrderRepository()
        let winner = StoredOrder(placed: Data.placed, requestHash: OrderRequestHash.make(Data.request))
        repository.update { $0.outcomes = [.duplicateKey] }
        let racing = RacingRepository(base: repository, winner: winner, key: Data.idempotencyKey)
        let result = try await Data.service(racing).place(Data.command())
        XCTAssertEqual(result, .replayed(Data.placed))

        let reusedRepository = FakeOrderRepository()
        reusedRepository.update { $0.outcomes = [.duplicateKey] }
        let other = StoredOrder(placed: Data.placed, requestHash: "different")
        let reused = await failure(reusedRepository, service: Data.service(RacingRepository(base: reusedRepository, winner: other, key: Data.idempotencyKey)))
        XCTAssertEqual(reused?.code, .idempotencyKeyReused)
    }

    func testCodeCollisionDrawsAgain() async throws {
        let repository = FakeOrderRepository()
        repository.update { $0.outcomes = [.codeCollision, .codeCollision] }
        let service = Data.service(repository, codes: FixedCodes(["BT-AAAAAA", "BT-BBBBBB", "BT-CCCCCC"]))
        let result = try await service.place(Data.command())
        guard case .created(let placed) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(placed.orderCode, "BT-CCCCCC")
        XCTAssertEqual(repository.inserted.map(\.orderCode), ["BT-AAAAAA", "BT-BBBBBB", "BT-CCCCCC"])
    }

    func testFiveCollisionsFailWithAnInternalError() async {
        let repository = FakeOrderRepository()
        repository.update { $0.outcomes = Array(repeating: .codeCollision, count: 9) }
        let error = await failure(repository)
        XCTAssertEqual(error?.code, .internalError)
        XCTAssertEqual(repository.inserted.count, OrderPlacementService.maxCodeDraws)
    }

    func testDatabaseOutageIsPassedOn() async {
        let repository = FakeOrderRepository()
        repository.update { $0.failure = APIError(.serviceUnavailable) }
        let error = await failure(repository)
        XCTAssertEqual(error?.code, .serviceUnavailable)
    }
}

/// Behaves like `base`, but the order of `key` only becomes visible after the
/// first lookup, as when a concurrent request commits in between.
final class RacingRepository: OrderRepository {
    let base: FakeOrderRepository
    let winner: StoredOrder
    let key: UUID
    private let lookups = LockedBox(0)

    init(base: FakeOrderRepository, winner: StoredOrder, key: UUID) {
        self.base = base
        self.winner = winner
        self.key = key
    }

    func loadReferenceData(shopID: UUID, productIDs: [UUID], slotID: UUID, districtID: UUID) async throws -> OrderReferenceData {
        try await base.loadReferenceData(shopID: shopID, productIDs: productIDs, slotID: slotID, districtID: districtID)
    }

    func findOrder(shopID: UUID, idempotencyKey: UUID) async throws -> StoredOrder? {
        lookups.set(lookups.value + 1)
        return lookups.value == 1 ? nil : winner
    }

    func countOrders(shopID: UUID, phone: String, since: Date) async throws -> Int {
        try await base.countOrders(shopID: shopID, phone: phone, since: since)
    }

    func insertOrder(_ order: NewOrder) async throws -> OrderInsertOutcome { try await base.insertOrder(order) }
}
