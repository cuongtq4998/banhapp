import XCTest

/// S-5 to S-8 against the stub backend: server date 2026-11-02, lead time 2 days, horizon 30 days;
/// 2026-11-05 and 2026-11-20 do not hold 3 cakes (`availability-ok.json`).
final class OrderFlowUITests: BanhUITestCase {
    @MainActor
    func testFromHomeToTheReviewWithTheRightTotalAndEveryEntryKept() throws {
        let app = launch()
        openOrderFlow(app)

        // S-5: empty first state, minimum 2 (AC-13).
        XCTAssertFalse(element(app, AccessibilityID.orderNext).isEnabled)
        waitFor(app, AccessibilityID.qtyMinHint)
        addCakes(app, Fake.banana, times: 1)
        XCTAssertFalse(element(app, AccessibilityID.orderNext).isEnabled)
        addCakes(app, Fake.banana, times: 1)
        XCTAssertTrue(element(app, AccessibilityID.orderNext).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.qtyMinHint).exists)
        addCakes(app, Fake.porkFat, times: 1)
        XCTAssertEqual(element(app, AccessibilityID.qtyTotal).label, "Tổng số bánh: 3")
        XCTAssertEqual(element(app, AccessibilityID.qtySubtotal).label, "Tiền bánh: 115.000 ₫")
        tap(app, AccessibilityID.orderNext)

        // S-6: lead time, full dates and the end of the horizon (AC-7, AC-8, AC-24).
        waitFor(app, AccessibilityID.dateCell("2026-11-04"))
        XCTAssertFalse(element(app, AccessibilityID.dateCell("2026-11-02")).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.dateCell("2026-11-03")).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.dateCell("2026-11-05")).isEnabled)
        XCTAssertTrue(element(app, AccessibilityID.dateCell("2026-11-06")).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.orderNext).isEnabled)
        tap(app, AccessibilityID.dateMonthNext)
        XCTAssertTrue(waitFor(app, AccessibilityID.dateCell("2026-12-02")).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.dateCell("2026-12-03")).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.dateMonthNext).isEnabled)
        tap(app, AccessibilityID.dateMonthPrevious)
        chooseDateAndSlot(app)

        // S-7: Next with an empty form shows the errors and stays (AC-12).
        waitFor(app, AccessibilityID.fieldName)
        tap(app, AccessibilityID.orderNext)
        waitFor(app, AccessibilityID.fieldError("name"))
        XCTAssertTrue(element(app, AccessibilityID.fieldError("phone")).exists)
        XCTAssertTrue(element(app, AccessibilityID.fieldError("address")).exists)
        XCTAssertTrue(element(app, AccessibilityID.fieldError("district")).exists)
        fillRecipient(app)

        // S-8: lines, fee 20.000, total 2 x 35.000 + 45.000 + 20.000 (AC-6, AC-14, AC-31).
        let total = waitFor(app, AccessibilityID.reviewTotal)
        XCTAssertTrue(total.label.contains("135.000 ₫"), total.label)
        XCTAssertTrue(element(app, AccessibilityID.reviewFee).label.contains("20.000 ₫"))
        XCTAssertTrue(element(app, AccessibilityID.reviewItem(Fake.banana)).label.contains("× 2"))
        XCTAssertTrue(element(app, AccessibilityID.reviewItem(Fake.porkFat)).label.contains("× 1"))
        XCTAssertFalse(element(app, AccessibilityID.reviewItem("00000000-0000-4000-8000-000000000013")).exists)
        XCTAssertTrue(element(app, AccessibilityID.reviewDate).label.contains("04/11/2026"))
        XCTAssertTrue(element(app, AccessibilityID.reviewTime).label.contains("14:00 – 16:00"))
        XCTAssertTrue(element(app, AccessibilityID.reviewName).label.contains("Nguyen Van An"))
        XCTAssertTrue(element(app, AccessibilityID.reviewPhone).label.contains("0912345678"))
        XCTAssertTrue(element(app, AccessibilityID.reviewAddress).label.contains("12 Duong So 3, Quận 5"))
        XCTAssertFalse(element(app, AccessibilityID.reviewNote).exists)
        XCTAssertFalse(element(app, AccessibilityID.reviewMessage).exists)
        XCTAssertTrue(element(app, AccessibilityID.reviewConfirm).isEnabled)
    }

    @MainActor
    func testGoingBackAndForwardKeepsTheEnteredData() throws {
        let app = launch()
        openOrderFlow(app)
        chooseThreeCakes(app)
        chooseDateAndSlot(app)
        fillRecipient(app)
        waitFor(app, AccessibilityID.reviewTotal)

        // Back to S-7 and S-6 by the back button (AC-18).
        tap(app, AccessibilityID.backButton)
        XCTAssertEqual(waitFor(app, AccessibilityID.fieldName).value as? String, "Nguyen Van An")
        XCTAssertEqual(element(app, AccessibilityID.fieldPhone).value as? String, "0912345678")
        XCTAssertEqual(element(app, AccessibilityID.districtFee).label, "Phí giao hàng: 20.000 ₫")
        tap(app, AccessibilityID.backButton)
        waitFor(app, AccessibilityID.dateCell("2026-11-04"))
        XCTAssertTrue(element(app, AccessibilityID.orderNext).isEnabled, "date and slot are still chosen")

        // Forward again, then Edit cakes from the review.
        tap(app, AccessibilityID.orderNext)
        tap(app, AccessibilityID.orderNext)
        waitFor(app, AccessibilityID.reviewTotal)
        tap(app, AccessibilityID.reviewEditCakes)
        XCTAssertEqual(quantityText(app, Fake.banana), "Bánh chuối, số lượng 2")
        XCTAssertEqual(quantityText(app, Fake.porkFat), "Bánh đậu xanh nhân mỡ, số lượng 1")
    }

    @MainActor
    func testRaisingTheQuantityOnAFullDateClearsItAndKeepsTheSlot() throws {
        let app = launch()
        openOrderFlow(app)
        addCakes(app, Fake.banana, times: 2)
        tap(app, AccessibilityID.orderNext)
        // 2 cakes still fit 2026-11-05 (98 of 100 booked).
        XCTAssertTrue(waitFor(app, AccessibilityID.dateCell("2026-11-05")).isEnabled)
        chooseDateAndSlot(app, date: "2026-11-05")
        waitFor(app, AccessibilityID.fieldName)

        tap(app, AccessibilityID.backButton)
        waitFor(app, AccessibilityID.dateCell("2026-11-05"))
        tap(app, AccessibilityID.backButton)
        waitFor(app, AccessibilityID.qtyIncrease(Fake.banana))
        addCakes(app, Fake.banana, times: 1)
        tap(app, AccessibilityID.orderNext)

        waitFor(app, AccessibilityID.dateClearedNotice)
        XCTAssertFalse(element(app, AccessibilityID.dateCell("2026-11-05")).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.orderNext).isEnabled)
        tap(app, AccessibilityID.dateCell("2026-11-04"))
        XCTAssertTrue(element(app, AccessibilityID.orderNext).isEnabled, "the slot was kept")
    }

    @MainActor
    func testTheNoteStopsAtTwoHundredCharactersWithAMessage() throws {
        let app = launch()
        openOrderFlow(app)
        chooseThreeCakes(app)
        chooseDateAndSlot(app)

        reveal(app, AccessibilityID.fieldNote)
        tap(app, AccessibilityID.fieldNote)
        app.typeText(String(repeating: "a", count: 205))

        XCTAssertEqual(element(app, AccessibilityID.noteCounter).label, "200/200")
        waitFor(app, AccessibilityID.fieldError("note"))
    }

    @MainActor
    func testTheNoteIsShownOnTheReviewWhenEntered() throws {
        let app = launch()
        openOrderFlow(app)
        chooseThreeCakes(app)
        chooseDateAndSlot(app)
        fillRecipient(app, note: "Giao som")
        XCTAssertTrue(waitFor(app, AccessibilityID.reviewNote).label.contains("Giao som"))
    }

    @MainActor
    func testAnInvalidPhoneIsRejectedNextToTheField() throws {
        let app = launch()
        openOrderFlow(app)
        chooseThreeCakes(app)
        chooseDateAndSlot(app)
        tap(app, AccessibilityID.fieldPhone)
        app.typeText("0281234567")
        tap(app, AccessibilityID.orderNext)
        waitFor(app, AccessibilityID.fieldError("phone"))
        XCTAssertFalse(element(app, AccessibilityID.reviewTotal).exists)
    }

    @MainActor
    func testTheDraftComesBackWhenTheFlowIsLeftAndReopened() throws {
        let app = launch()
        openOrderFlow(app)
        addCakes(app, Fake.banana, times: 3)
        tap(app, AccessibilityID.backButton)
        waitFor(app, AccessibilityID.homeOrder)
        openOrderFlow(app)
        XCTAssertEqual(quantityText(app, Fake.banana), "Bánh chuối, số lượng 3")
    }

    @MainActor
    func testWhenAvailabilityCannotBeLoadedTheDateStepShowsAnErrorWithRetry() throws {
        let app = launch(stub: LaunchArgument.stubModeAvailabilityFails)
        openOrderFlow(app)
        chooseThreeCakes(app)
        waitFor(app, AccessibilityID.errorState)
        XCTAssertTrue(element(app, AccessibilityID.errorRetry).exists)
        XCTAssertFalse(element(app, AccessibilityID.orderNext).isEnabled)
    }
}
