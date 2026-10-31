import XCTest

/// S-8 sending states and S-9 against the stub backend (`-BanhStubBackend order:<scenario>`). The
/// order is 2 x Bánh chuối + 1 x Bánh đậu xanh nhân mỡ for 2026-11-04, total 135.000 ₫.
/// Test case ids are those of docs/test/place-order-tests/03-cases-ui.md.
final class OrderSendUITests: BanhUITestCase {
    private func openReview(_ scenario: String) -> XCUIApplication {
        let app = launch(stub: LaunchArgument.order(scenario))
        openOrderFlow(app)
        chooseThreeCakes(app)
        chooseDateAndSlot(app)
        fillRecipient(app)
        waitFor(app, AccessibilityID.reviewTotal)
        return app
    }

    /// The text of the banner: its container has no label of its own.
    private func bannerText(_ app: XCUIApplication) -> String {
        waitFor(app, AccessibilityID.reviewMessage).staticTexts.firstMatch.label
    }

    private func confirm(_ app: XCUIApplication) { tap(app, AccessibilityID.reviewConfirm) }

    private func assertConfirmed(_ app: XCUIApplication, code: String = LaunchArgument.confirmationCode,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let shown = waitFor(app, AccessibilityID.confirmationCode, file: file, line: line)
        XCTAssertTrue(shown.label.contains(code), shown.label, file: file, line: line)
    }

    // TC-119, TC-121, TC-128, TC-139 (AC-15, AC-16, AC-17, AC-25)
    @MainActor
    func testTC119TheOrderIsReceivedAndTheConfirmationShowsOnlyTheCodeAndContacts() throws {
        let app = openReview(LaunchArgument.orderSuccess)
        confirm(app)
        assertConfirmed(app)
        waitFor(app, AccessibilityID.confirmationTitle)
        waitFor(app, AccessibilityID.confirmationMessage)
        XCTAssertTrue(element(app, AccessibilityID.confirmationZalo).isEnabled)
        XCTAssertTrue(element(app, AccessibilityID.confirmationPhone).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.reviewConfirm).exists)
        XCTAssertFalse(element(app, AccessibilityID.backButton).exists, "no way back to S-8")
        let message = element(app, AccessibilityID.confirmationMessage).label.lowercased()
        for forbidden in ["chấp nhận", "đảm bảo", "thanh toán"] { XCTAssertFalse(message.contains(forbidden)) }

        // The contact buttons open (the stub opener accepts every link): no toast.
        tap(app, AccessibilityID.confirmationZalo)
        tap(app, AccessibilityID.confirmationPhone)
        XCTAssertFalse(element(app, AccessibilityID.toast).exists)
    }

    // TC-139: Home clears the flow, a new order starts empty.
    @MainActor
    func testTC139HomeFromTheConfirmationClearsTheDraft() throws {
        let app = openReview(LaunchArgument.orderSuccess)
        confirm(app)
        assertConfirmed(app)
        tap(app, AccessibilityID.confirmationHome)
        waitFor(app, AccessibilityID.homeOrder)
        openOrderFlow(app)
        XCTAssertEqual(quantityText(app, Fake.banana), "Bánh chuối, số lượng 0")
        XCTAssertFalse(element(app, AccessibilityID.orderNext).isEnabled)
    }

    // TC-266: the back gesture on S-9 goes to S-2, never to S-8.
    @MainActor
    func testTC266BackFromTheConfirmationGoesToHome() throws {
        let app = openReview(LaunchArgument.orderSuccess)
        confirm(app)
        assertConfirmed(app)
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        waitFor(app, AccessibilityID.homeOrder)
        XCTAssertFalse(element(app, AccessibilityID.reviewConfirm).exists)
    }

    // TC-123 (AC-19): five quick taps send once; the review is inert while sending.
    @MainActor
    func testTC123SendingDisablesTheReviewAndFiveTapsSendOnce() throws {
        let app = openReview(LaunchArgument.orderSlow)
        let button = element(app, AccessibilityID.reviewConfirm)
        for _ in 0..<5 { button.tap() }
        XCTAssertFalse(button.isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.reviewEditCakes).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.backButton).isEnabled)
        XCTAssertTrue(button.label.contains("Đang gửi đơn"), button.label)
        assertConfirmed(app) // a second POST would have shown the other code
    }

    // TC-124, TC-138 (AC-20): offline; nothing confirmed, data kept, retry sends once.
    @MainActor
    func testTC124OfflineShowsTheMessageAndRetryWorks() throws {
        let app = openReview(LaunchArgument.orderOffline)
        confirm(app)
        let message = bannerText(app)
        XCTAssertTrue(message.contains("không có kết nối mạng"), message)
        XCTAssertFalse(element(app, AccessibilityID.confirmationCode).exists)
        XCTAssertTrue(element(app, AccessibilityID.reviewConfirm).isEnabled)
        XCTAssertTrue(element(app, AccessibilityID.reviewName).label.contains("Nguyen Van An"))
        tap(app, AccessibilityID.reviewMessageAction)
        assertConfirmed(app)
    }

    // TC-157, TC-144 (AC-19, ADR-0008): the answer is lost; the retry uses the same key, so the
    // stored order comes back and not a second one.
    @MainActor
    func testTC157ATimeoutRetryReturnsTheSameOrder() throws {
        let app = openReview(LaunchArgument.orderLostAnswer)
        confirm(app)
        let message = bannerText(app)
        XCTAssertTrue(message.contains("mất quá nhiều thời gian"), message)
        confirm(app)
        assertConfirmed(app)
    }

    // TC-127 (AC-23): price changed; new prices, message, confirm again at the new total.
    @MainActor
    func testTC127PriceChangedRefreshesTheReviewAndTheSecondConfirmSucceeds() throws {
        let app = openReview(LaunchArgument.orderPriceChanged)
        confirm(app)
        let message = bannerText(app)
        XCTAssertTrue(message.contains("Giá đã thay đổi"), message)
        XCTAssertTrue(element(app, AccessibilityID.reviewTotal).label.contains("145.000 ₫"))
        XCTAssertTrue(element(app, AccessibilityID.reviewItem(Fake.banana)).label.contains("80.000 ₫"))
        XCTAssertTrue(element(app, AccessibilityID.reviewConfirm).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.confirmationCode).exists)
        confirm(app)
        assertConfirmed(app)
    }

    // TC-113, TC-126 (AC-9, AC-22): the date filled up meanwhile.
    @MainActor
    func testTC113DateCapacityBlocksConfirmAndOpensTheDateStep() throws {
        let app = openReview("error-date-capacity")
        confirm(app)
        let message = bannerText(app)
        XCTAssertTrue(message.contains("05/11/2026"), message)
        XCTAssertFalse(element(app, AccessibilityID.reviewConfirm).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.confirmationCode).exists)
        tap(app, AccessibilityID.reviewMessageAction)
        waitFor(app, AccessibilityID.dateCell("2026-11-04"))
        XCTAssertTrue(element(app, AccessibilityID.orderNext).isEnabled, "entered data is kept")
    }

    // TC-117, TC-138: the other rule errors, each with the action to its step.
    @MainActor
    func testTC138RuleErrorsOpenTheStepThatFixesThem() throws {
        let cases: [(scenario: String, check: (XCUIApplication) -> Void)] = [
            ("error-min-qty", { self.waitFor($0, AccessibilityID.qtyIncrease(Fake.banana)) }),
            ("error-date-lead", { self.waitFor($0, AccessibilityID.dateCell("2026-11-04")) }),
            ("error-date-horizon", { self.waitFor($0, AccessibilityID.dateCell("2026-11-04")) }),
            ("error-slot-unavailable", { self.waitFor($0, AccessibilityID.slotChip(Fake.slotAfternoon)) }),
            ("error-district-unserved", { self.waitFor($0, AccessibilityID.fieldDistrict) }),
            ("error-product-unavailable", { self.waitFor($0, AccessibilityID.qtyIncrease(Fake.banana)) }),
        ]
        for (scenario, check) in cases {
            let app = openReview(scenario)
            confirm(app)
            waitFor(app, AccessibilityID.reviewMessage)
            XCTAssertFalse(element(app, AccessibilityID.reviewConfirm).isEnabled, scenario)
            tap(app, AccessibilityID.reviewMessageAction)
            check(app)
            app.terminate()
        }
    }

    // TC-138: server errors and the rate limit are "not sent" with retry; confirm stays on.
    @MainActor
    func testTC138NotSentErrorsKeepConfirmEnabledAndRetrySends() throws {
        for scenario in ["error-internal-error", "error-service-unavailable", "error-rate-limited", "error-ordering-paused"] {
            let app = openReview(scenario)
            confirm(app)
            let message = bannerText(app)
            XCTAssertTrue(message.contains("chưa được gửi"), "\(scenario): \(message)")
            XCTAssertTrue(element(app, AccessibilityID.reviewConfirm).isEnabled, scenario)
            XCTAssertFalse(element(app, AccessibilityID.confirmationCode).exists, scenario)
            tap(app, AccessibilityID.reviewMessageAction)
            assertConfirmed(app)
            app.terminate()
        }
    }

    // AC-13: the server's field errors come back next to the fields on S-7.
    @MainActor
    func testValidationFailedShowsTheErrorsOnTheRecipientStep() throws {
        let app = openReview("error-validation-failed")
        confirm(app)
        // The fixture also names the (valid) name field; focusing it re-validates and clears that one,
        // as for any field that is valid (UI document 5.7), so only the phone error stays.
        waitFor(app, AccessibilityID.fieldError("phone"))
        XCTAssertNotNil(waitFor(app, AccessibilityID.orderTitle))
        XCTAssertFalse(element(app, AccessibilityID.confirmationCode).exists)
    }
}
