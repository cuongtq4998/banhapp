import XCTest

/// S-7 privacy notice (FR-20, AC-30) and the S-8 reminder link. The browser is a stub in these runs.
final class PrivacyUITests: BanhUITestCase {
    private func openRecipient(_ app: XCUIApplication) {
        openOrderFlow(app)
        chooseThreeCakes(app)
        chooseDateAndSlot(app)
        waitFor(app, AccessibilityID.fieldName)
    }

    @MainActor
    func testTheNoticeIsOnScreenAboveTheNameFieldAndCannotBeDismissed() throws {
        let app = launch()
        openRecipient(app)
        let card = waitFor(app, AccessibilityID.privacyCard)
        XCTAssertTrue(card.isHittable || card.exists)
        XCTAssertLessThan(card.frame.minY, element(app, AccessibilityID.fieldName).frame.minY)
        for id in [AccessibilityID.privacyTitle, AccessibilityID.privacyBody, AccessibilityID.privacyDraft, AccessibilityID.privacyLink] {
            XCTAssertTrue(element(app, id).exists, id)
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'order.privacy'")).count, 1,
                       "the link is the only control of the card")
    }

    @MainActor
    func testTheLinkOpensTheBrowserAndClosingKeepsTheFields() throws {
        let app = launch()
        openRecipient(app)
        tap(app, AccessibilityID.fieldName)
        app.typeText("Nguyen Van An")
        tap(app, AccessibilityID.privacyLink)
        waitFor(app, AccessibilityID.privacyBrowserStub)
        tap(app, AccessibilityID.privacyBrowserStubClose)
        waitFor(app, AccessibilityID.privacyCard)
        XCTAssertEqual(element(app, AccessibilityID.fieldName).value as? String, "Nguyen Van An")
    }

    @MainActor
    func testTheNoticeShowsAgainAfterGoingBackFromTheReview() throws {
        let app = launch()
        openRecipient(app)
        fillRecipient(app)
        waitFor(app, AccessibilityID.reviewPrivacy)
        waitFor(app, AccessibilityID.reviewPrivacyLink)
        tap(app, AccessibilityID.reviewEditRecipient)
        waitFor(app, AccessibilityID.privacyCard)
    }

    @MainActor
    func testTheReviewLinkOpensTheBrowser() throws {
        let app = launch()
        openRecipient(app)
        fillRecipient(app)
        tap(app, AccessibilityID.reviewPrivacyLink)
        waitFor(app, AccessibilityID.privacyBrowserStub)
    }

    @MainActor
    func testAFailedOpenShowsTheToastAndTheTextStaysReadable() throws {
        let app = launch(stub: LaunchArgument.stubModePrivacyFails)
        openRecipient(app)
        tap(app, AccessibilityID.privacyLink)
        waitFor(app, AccessibilityID.toast)
        XCTAssertTrue(element(app, AccessibilityID.privacyBody).exists)
    }

    @MainActor
    func testAFailedNextStillFocusesTheFirstFailingFieldNotTheCard() throws {
        let app = launch()
        openRecipient(app)
        tap(app, AccessibilityID.orderNext)
        waitFor(app, AccessibilityID.fieldError("name"))
        XCTAssertTrue(element(app, AccessibilityID.privacyCard).exists)
        XCTAssertEqual(element(app, AccessibilityID.fieldName).value(forKey: "hasKeyboardFocus") as? Bool, true)
    }
}
