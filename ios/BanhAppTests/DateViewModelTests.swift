import BanhContracts
import XCTest
@testable import BanhApp

/// S-6 against `availability-ok.json` (server date 2026-11-02, lead 2, horizon 30): AC-7, AC-8, AC-10, AC-24.
@MainActor
final class DateViewModelTests: XCTestCase {
    private func make(
        cakes: Int = 3, api: StubAvailability? = nil, draft: OrderDraft? = nil
    ) async throws -> (DateViewModel, OrderFlow, StubAvailability) {
        var start = draft ?? OrderDraft(savedAt: OrderTestSupport.now)
        if draft == nil {
            let ok = try CatalogTestData.okCatalog()
            start.setQuantity(cakes, of: ok.products[0].productID, name: ok.products[0].name)
        }
        let flow = try await OrderTestSupport.flow(draft: start)
        let api = try api ?? StubAvailability.fixture()
        return (DateViewModel(flow: flow, api: api), flow, api)
    }

    private func date(_ iso: String) -> ShopDate { ShopDate(iso: iso)! }

    func testAsksForTheTotalNumberOfCakes() async throws {
        let (model, _, api) = try await make(cakes: 3)
        await model.load()
        XCTAssertEqual(api.cakesAsked, [3])
    }

    func testNoDateBeforeTheLeadTimeCanBeChosen() async throws {
        let (model, flow, _) = try await make()
        await model.load()
        for iso in ["2026-10-31", "2026-11-02", "2026-11-03"] {
            XCTAssertEqual(model.state(of: date(iso)), .tooSoon, iso)
            model.select(date(iso))
        }
        XCTAssertNil(flow.draft.date)
        XCTAssertEqual(model.state(of: date("2026-11-04")), .available)
    }

    func testTheLastDateOfTheHorizonIsSelectableAndLaterOnesAreNot() async throws {
        let (model, flow, _) = try await make()
        await model.load()
        XCTAssertEqual(model.state(of: date("2026-12-02")), .available)
        XCTAssertEqual(model.state(of: date("2026-12-03")), .tooFar)
        model.select(date("2026-12-03"))
        XCTAssertNil(flow.draft.date)
        model.select(date("2026-12-02"))
        XCTAssertEqual(flow.draft.date, date("2026-12-02"))
    }

    func testFullDatesCannotBeChosen() async throws {
        let (model, flow, _) = try await make(cakes: 3)
        await model.load()
        XCTAssertEqual(model.state(of: date("2026-11-05")), .full)
        XCTAssertEqual(model.state(of: date("2026-11-20")), .full)
        model.select(date("2026-11-05"))
        XCTAssertNil(flow.draft.date)
    }

    func testSelectionReplacesThePreviousOne() async throws {
        let (model, flow, _) = try await make()
        await model.load()
        model.select(date("2026-11-04"))
        XCTAssertEqual(model.state(of: date("2026-11-04")), .selected)
        model.select(date("2026-11-06"))
        XCTAssertEqual(flow.draft.date, date("2026-11-06"))
        XCTAssertEqual(model.state(of: date("2026-11-04")), .available)
    }

    func testChoosingASlotNeverChangesTheDates() async throws {
        let (model, _, _) = try await make()
        await model.load()
        let before = (0...30).map { model.state(of: date("2026-11-02").adding(days: $0)) }
        for slot in model.slots { model.select(slot) }
        let after = (0...30).map { model.state(of: date("2026-11-02").adding(days: $0)) }
        XCTAssertEqual(before, after)
    }

    func testTheSameFixedSlotListIsOfferedWhateverTheDate() async throws {
        let (model, _, _) = try await make()
        await model.load()
        let initial = model.slots
        model.select(date("2026-11-04"))
        XCTAssertEqual(model.slots, initial)
        XCTAssertEqual(initial.map(\.label), ["08:00 – 10:00", "10:00 – 12:00", "14:00 – 16:00", "16:00 – 18:00"])
    }

    func testNextNeedsBothADateAndASlot() async throws {
        let (model, _, _) = try await make()
        await model.load()
        XCTAssertFalse(model.canContinue)
        model.select(date("2026-11-04"))
        XCTAssertFalse(model.canContinue)
        model.select(model.slots[0])
        XCTAssertTrue(model.canContinue)
    }

    func testAChosenDateThatNoLongerFitsIsClearedAndTheSlotIsKept() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(3, of: ok.products[0].productID, name: ok.products[0].name)
        draft.date = date("2026-11-05")
        draft.slotID = OrderTestSupport.id(32)
        let (model, flow, _) = try await make(draft: draft)

        await model.load()

        XCTAssertNil(flow.draft.date)
        XCTAssertEqual(flow.draft.slotID, OrderTestSupport.id(32))
        XCTAssertTrue(model.dateWasCleared)
        model.select(date("2026-11-04"))
        XCTAssertFalse(model.dateWasCleared)
    }

    func testAStillValidDateIsKeptWithoutAMessage() async throws {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(3, of: ok.products[0].productID, name: ok.products[0].name)
        draft.date = date("2026-11-06")
        let (model, flow, _) = try await make(draft: draft)
        await model.load()
        XCTAssertEqual(flow.draft.date, date("2026-11-06"))
        XCTAssertFalse(model.dateWasCleared)
        XCTAssertEqual(model.state(of: date("2026-11-06")), .selected)
    }

    func testMonthsRunFromTodaysMonthToTheMonthOfTheHorizon() async throws {
        let (model, _, _) = try await make()
        await model.load()
        // The first selectable date (2026-11-04) is in the first month.
        XCTAssertEqual(model.shownMonth, date("2026-11-01"))
        XCTAssertFalse(model.canShowPreviousMonth)
        XCTAssertTrue(model.canShowNextMonth)
        model.showNextMonth()
        XCTAssertEqual(model.shownMonth, date("2026-12-01"))
        XCTAssertFalse(model.canShowNextMonth)
        model.showNextMonth()
        XCTAssertEqual(model.shownMonth, date("2026-12-01"))
        model.showPreviousMonth()
        XCTAssertEqual(model.shownMonth, date("2026-11-01"))
    }

    func testRangeHintNamesTheFirstAndLastDate() async throws {
        let (model, _, _) = try await make()
        await model.load()
        XCTAssertEqual(model.rangeHint, "Nhận bánh từ 04/11/2026 đến 02/12/2026.")
    }

    func testEveryDateFullShowsTheEmptyState() async throws {
        let allFull = AvailabilityResponse(
            serverDate: "2026-11-02",
            dates: (0...30).map { AvailabilityDate(date: date("2026-11-02").adding(days: $0).iso, available: false, reason: .full) }
        )
        let (model, _, _) = try await make(api: StubAvailability(.success(allFull)))
        await model.load()
        XCTAssertTrue(model.hasNoSelectableDate)
        XCTAssertFalse(model.canContinue)
    }

    func testOfflineAndServerFailuresAreErrorStates() async throws {
        let (model, _, api) = try await make(api: StubAvailability(.failure(.networkUnavailable)))
        await model.load()
        XCTAssertEqual(model.availability, .failed(.network))
        api.set(.failure(.timeout))
        await model.load()
        XCTAssertEqual(model.availability, .failed(.other))
        XCTAssertFalse(model.canContinue)
        api.set(.success(try Fixtures.decode(AvailabilityResponse.self, from: "availability-ok.json")))
        await model.load()
        guard case .ready = model.availability else { return XCTFail("Retry should recover") }
    }
}
