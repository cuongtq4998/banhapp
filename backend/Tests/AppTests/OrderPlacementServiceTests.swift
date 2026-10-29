import XCTest
import BanhContracts
@testable import App

final class OrderPlacementServiceTests: XCTestCase {
    typealias Data = OrderTestData

    func expectFailure(
        _ code: APIErrorCode, details: [String: JSONValue]? = nil, repository: FakeOrderRepository,
        request: OrderRequest = Data.request, service: OrderPlacementService? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) async {
        do {
            _ = try await (service ?? Data.service(repository)).place(Data.command(request))
            XCTFail("expected \(code)", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error.code, code, file: file, line: line)
            if let details { XCTAssertEqual(error.details, details, file: file, line: line) }
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }

    func testPlacesTheOrderAfterTheChecksInTheDocumentedOrder() async throws {
        let repository = FakeOrderRepository()
        let result = try await Data.service(repository).place(Data.command())
        XCTAssertEqual(result, .created(PlacedOrder(orderCode: "BT-7K3M9Q", createdAt: Data.placed.createdAt)))
        XCTAssertEqual(repository.calls, ["load", "find", "count", "insert"])
    }

    func testStoresTheServerPricesAndSnapshots() async throws {
        let repository = FakeOrderRepository()
        _ = try await Data.service(repository).place(Data.command())
        let order = try XCTUnwrap(repository.inserted.first)
        XCTAssertEqual(order.lines, [PricedLine(productID: Data.productID, productName: "Bánh chuối", unitPriceVND: 50_000, quantity: 2)])
        XCTAssertEqual(order.itemsSubtotalVND, 100_000)
        XCTAssertEqual(order.totalVND, 120_000)
        XCTAssertEqual(order.dailyLimit, 100)
        XCTAssertEqual(order.slot.startTime, "08:00:00")
        XCTAssertEqual(order.district.name, "Quận 1")
        XCTAssertEqual(order.request.customerPhone, Data.phone)
        XCTAssertEqual(order.createdAt, AvailabilityTestData.clock.instant)
        XCTAssertEqual(order.requestHash, OrderRequestHash.make(Data.request))
    }

    func testReplayReturnsTheStoredResultWithoutWriting() async throws {
        let repository = FakeOrderRepository()
        let service = Data.service(repository)
        let first = try await service.place(Data.command())
        repository.update { $0.calls = [] }
        let second = try await service.place(Data.command())
        guard case .created(let created) = first, case .replayed(let replayed) = second else { return XCTFail("\(first) \(second)") }
        XCTAssertEqual(created, replayed)
        XCTAssertEqual(repository.calls, ["load", "find"])
        XCTAssertEqual(repository.inserted.count, 1)
    }

    func testReplayWinsEvenWhenTheProductWasHiddenSince() async throws {
        let repository = FakeOrderRepository()
        let service = Data.service(repository)
        _ = try await service.place(Data.command())
        repository.update {
            $0.data = OrderReferenceData(rules: Data.rules, minQty: 2, products: [:], slot: nil, district: nil)
        }
        let replay = try await service.place(Data.command())
        XCTAssertEqual(replay, .replayed(Data.placed))
    }

    func testSameKeyWithAnotherBodyIsReused() async {
        let repository = FakeOrderRepository()
        repository.update { $0.stored[Data.idempotencyKey] = StoredOrder(placed: Data.placed, requestHash: "other") }
        await expectFailure(.idempotencyKeyReused, repository: repository)
        XCTAssertEqual(repository.inserted.count, 0)
    }

    func testUnknownAndInactiveProductsAreListedInRequestOrder() async {
        let unknown = UUID(uuidString: "0b8f1f0e-1111-4a00-8000-0000000000ff")!
        let request = OrderRequest(
            items: [.init(productID: Data.inactiveProductID, quantity: 1), .init(productID: Data.productID, quantity: 1), .init(productID: unknown, quantity: 1)],
            deliveryDate: Data.request.deliveryDate, slotID: Data.slotID, customerName: "A", customerPhone: Data.phone,
            customerAddress: "B", districtID: Data.districtID, note: nil, expectedTotalVND: 1
        )
        let repository = FakeOrderRepository()
        repository.update { $0.data = OrderReferenceData(
            rules: AvailabilityRules(leadDays: 2, maxDaysAhead: 30, dailyLimit: 100, activeProductCount: 3, maxQtyPerCake: 99),
            minQty: 2, products: Data.referenceData.products, slot: nil, district: nil
        ) }
        await expectFailure(.productUnavailable, details: [
            "product_ids": .array([.string(Data.inactiveProductID.uuidString.lowercased()), .string(unknown.uuidString.lowercased())])
        ], repository: repository, request: request)
        XCTAssertEqual(repository.calls, ["load", "find"])
    }

    func testSlotThenDistrictFailuresFollowTheDocumentedOrder() async {
        let repository = FakeOrderRepository()
        let data = Data.referenceData
        repository.update { $0.data = OrderReferenceData(rules: data.rules, minQty: 2, products: data.products, slot: nil, district: nil) }
        await expectFailure(.slotUnavailable, repository: repository)
        repository.update { $0.data = OrderReferenceData(rules: data.rules, minQty: 2, products: data.products, slot: data.slot, district: nil) }
        await expectFailure(.districtUnserved, repository: repository)
        let inactive = OrderDistrictRecord(id: Data.districtID, name: "X", deliveryFeeVND: 1, isActive: false)
        repository.update { $0.data = OrderReferenceData(rules: data.rules, minQty: 2, products: data.products, slot: data.slot, district: inactive) }
        await expectFailure(.districtUnserved, repository: repository)
    }

    func testMinimumQuantity() async {
        let request = Data.request.replacing(items: [.init(productID: Data.productID, quantity: 1)], expected: 70_000)
        await expectFailure(.minQty, details: ["min_qty": .int(2)], repository: FakeOrderRepository(), request: request)
    }

    func testLeadAndHorizonBoundaries() async throws {
        for (date, ok) in [("2026-11-03", false), ("2026-11-04", true), ("2026-12-02", true), ("2026-12-03", false)] {
            let repository = FakeOrderRepository()
            let request = Data.request.replacing(date: AvailabilityTestData.date(date))
            if ok {
                _ = try await Data.service(repository).place(Data.command(request))
            } else {
                let code: APIErrorCode = date < "2026-11-04" ? .dateLead : .dateHorizon
                let details: [String: JSONValue] = code == .dateLead ? ["lead_days": .int(2)] : ["max_days_ahead": .int(30)]
                await expectFailure(code, details: details, repository: repository, request: request)
                XCTAssertEqual(repository.inserted.count, 0, date)
            }
        }
    }

    func testTodayIsTheShopDateNotTheUTCDate() async {
        // 18:00 UTC on 2 November is 01:00 on 3 November in Vietnam: the first date is 5 November.
        let service = OrderPlacementService(
            repository: FakeOrderRepository(), calendar: ShopCalendar(clock: FixedWallClock(instant: AvailabilityTestData.shopInstant("2026-11-03", hour: 1, minute: 0))),
            orderCodes: FixedCodes(["BT-7K3M9Q"]), maxOrdersPerPhonePerDay: 5
        )
        let request = Data.request.replacing(date: AvailabilityTestData.date("2026-11-04"))
        await expectFailure(.dateLead, repository: FakeOrderRepository(), request: request, service: service)
    }

    func testPriceChangeCarriesTheCurrentPrices() async {
        let repository = FakeOrderRepository()
        let data = Data.referenceData
        var products = data.products
        products[Data.productID] = OrderProductRecord(id: Data.productID, name: "Bánh chuối", priceVND: 55_000, isActive: true)
        repository.update { $0.data = OrderReferenceData(rules: data.rules, minQty: 2, products: products, slot: data.slot, district: data.district) }
        await expectFailure(.priceChanged, details: [
            "items": .array([.object(["product_id": .string(Data.productID.uuidString.lowercased()), "price_vnd": .int(55_000)])]),
            "delivery_fee_vnd": .int(20_000), "total_vnd": .int(130_000)
        ], repository: repository)
        XCTAssertEqual(repository.calls, ["load", "find"])
    }

    func testSettingsLimitsAreFieldErrorsBeforeAnyLookup() async {
        let request = Data.request.replacing(items: [.init(productID: Data.productID, quantity: 99)], expected: 1)
        let repository = FakeOrderRepository()
        repository.update { $0.data = OrderReferenceData(
            rules: AvailabilityRules(leadDays: 2, maxDaysAhead: 30, dailyLimit: 100, activeProductCount: 2, maxQtyPerCake: 10),
            minQty: 2, products: Data.referenceData.products, slot: nil, district: nil
        ) }
        do {
            _ = try await Data.service(repository).place(Data.command(request))
            XCTFail("expected a validation error")
        } catch let error as APIError {
            XCTAssertEqual(error.code, .validationFailed)
            XCTAssertEqual(error.fields?.map(\.field), ["items[0].quantity"])
        } catch { XCTFail("\(error)") }
        XCTAssertEqual(repository.calls, ["load"])
    }
}

extension OrderRequest {
    func replacing(items: [Line]? = nil, date: BusinessDate? = nil, expected: Int? = nil) -> OrderRequest {
        OrderRequest(
            items: items ?? self.items, deliveryDate: date ?? deliveryDate, slotID: slotID, customerName: customerName,
            customerPhone: customerPhone, customerAddress: customerAddress, districtID: districtID, note: note,
            expectedTotalVND: expected ?? expectedTotalVND
        )
    }
}
