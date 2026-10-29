import BanhContracts
import XCTest
@testable import BanhApp

/// S-7: AC-11, AC-12, AC-26 and the field rules of ADR-0009.
@MainActor
final class RecipientViewModelTests: XCTestCase {
    private func make() async throws -> (RecipientViewModel, OrderFlow) {
        let flow = try await OrderTestSupport.flow()
        return (RecipientViewModel(flow: flow), flow)
    }

    private func fillValid(_ model: RecipientViewModel) throws {
        model.setName("Nguyễn Văn An")
        model.setPhone("091 234 5678")
        model.setAddress("12 Đường Số 3")
        let district = try XCTUnwrap(model.selectedDistrict ?? firstDistrict(model))
        model.select(district)
    }

    private func firstDistrict(_ model: RecipientViewModel) -> RecipientViewModel.DistrictRow? {
        if case .ready(let rows) = model.districts { rows.first } else { nil }
    }

    func testEmptyFormShowsAnErrorForEveryRequiredFieldAndDoesNotAdvance() async throws {
        let (model, _) = try await make()
        XCTAssertFalse(model.validateAll())
        XCTAssertEqual(model.problems[.name], .nameRequired)
        XCTAssertEqual(model.problems[.phone], .phoneRequired)
        XCTAssertEqual(model.problems[.address], .addressRequired)
        XCTAssertEqual(model.problems[.district], .districtRequired)
        XCTAssertNil(model.problems[.note])
        XCTAssertEqual(model.focusRequest, .name)
    }

    func testFocusGoesToTheFirstFailingField() async throws {
        let (model, _) = try await make()
        model.setName("An")
        XCTAssertFalse(model.validateAll())
        XCTAssertEqual(model.focusRequest, .phone)
        model.focusHandled()
        XCTAssertNil(model.focusRequest)
    }

    func testAWrongPhoneIsInvalidNotMissing() async throws {
        let (model, _) = try await make()
        try fillValid(model)
        model.setPhone("0281234567") // landline
        XCTAssertFalse(model.validateAll())
        XCTAssertEqual(model.problems[.phone], .phoneInvalid)
        XCTAssertEqual(model.focusRequest, .phone)
    }

    func testAnErrorClearsWhenItsFieldBecomesValid() async throws {
        let (model, _) = try await make()
        _ = model.validateAll()
        model.setName("An")
        XCTAssertNil(model.problems[.name])
        XCTAssertNotNil(model.problems[.phone])
        model.setPhone("12")
        XCTAssertEqual(model.problems[.phone], .phoneInvalid)
        model.setPhone("+84912345678")
        XCTAssertNil(model.problems[.phone])
    }

    func testAValidFormAdvances() async throws {
        let (model, flow) = try await make()
        try fillValid(model)
        XCTAssertTrue(model.validateAll())
        XCTAssertTrue(model.problems.isEmpty)
        XCTAssertEqual(flow.draft.phone, "091 234 5678")
    }

    func testWhitespaceOnlyNameIsMissing() async throws {
        let (model, _) = try await make()
        try fillValid(model)
        model.setName("   ")
        XCTAssertFalse(model.validateAll())
        XCTAssertEqual(model.problems[.name], .nameRequired)
    }

    func testInputLimitsCutSilently() async throws {
        let (model, _) = try await make()
        model.setName(String(repeating: "a", count: 130))
        model.setAddress(String(repeating: "b", count: 300))
        XCTAssertEqual(model.name.count, 100)
        XCTAssertEqual(model.address.count, 250)
        XCTAssertTrue(model.problems.isEmpty)
    }

    func testANoteOfTwoHundredIsAcceptedAndShown() async throws {
        let (model, flow) = try await make()
        model.setNote(String(repeating: "a", count: 200))
        XCTAssertEqual(flow.draft.note.count, 200)
        XCTAssertNil(model.problems[.note])
        XCTAssertEqual(model.noteLength, 200)
        XCTAssertEqual(model.noteMaxLength, 200)
    }

    func testThe201stCharacterIsRejectedWithAMessageAndPastedTextIsCut() async throws {
        let (model, flow) = try await make()
        model.setNote(String(repeating: "a", count: 200))
        model.setNote(String(repeating: "a", count: 201))
        XCTAssertEqual(flow.draft.note.count, 200)
        XCTAssertEqual(model.problems[.note], .noteTooLong)

        model.setNote(String(repeating: "b", count: 500))
        XCTAssertEqual(flow.draft.note.count, 200)

        model.setNote(String(repeating: "a", count: 199))
        XCTAssertNil(model.problems[.note])
    }

    func testAnEmptyNoteIsFine() async throws {
        let (model, _) = try await make()
        try fillValid(model)
        XCTAssertTrue(model.validateAll())
    }

    func testOnlyServedDistrictsCanBeChosenAndAnUnknownOneCountsAsNotChosen() async throws {
        let (model, flow) = try await make()
        guard case .ready(let rows) = model.districts else { return XCTFail("Not ready") }
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(rows[2].feeText, "20.000 ₫")
        model.select(rows[2])
        XCTAssertEqual(model.selectedDistrict, rows[2])
        flow.setDistrict(OrderTestSupport.id(999))
        XCTAssertNil(model.selectedDistrict)
    }

    func testNoDistrictsInTheCatalogDisablesNext() async throws {
        let empty = try Fixtures.decode(CatalogResponse.self, from: "catalog-empty.json")
        let flow = try await OrderTestSupport.flow(catalog: empty)
        XCTAssertFalse(RecipientViewModel(flow: flow).canContinue)
        let (model, _) = try await make()
        XCTAssertTrue(model.canContinue)
    }
}
