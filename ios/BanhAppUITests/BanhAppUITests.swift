import XCTest

/// Runs the app against the in-process stub backend of debug builds (`-BanhStubBackend`), so the tests
/// need no network and see the same four fake cakes as `contracts/fixtures/catalog-ok.json`.
final class BanhAppUITests: XCTestCase {
    private static let firstProductID = "00000000-0000-4000-8000-000000000011"
    private static let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(stub mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-\(LaunchArgument.stubBackend)", mode]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func testMainFlowFromLaunchToTheOrderStub() throws {
        let app = launch(stub: LaunchArgument.stubModeCatalog)

        // S-1 shows for 1 to 2 s, shorter than the test's first query can be relied on to catch, so
        // the launch screen is covered by the LaunchGate unit tests; the flow starts at S-2.
        let shopName = element(app, AccessibilityID.homeShopName)
        XCTAssertTrue(shopName.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(shopName.label, "Tiệm Bánh An Nhiên")
        XCTAssertEqual(element(app, AccessibilityID.homeGreeting).label, "Bánh làm thủ công, giao tận nơi.")
        XCTAssertTrue(element(app, AccessibilityID.homeZalo).isEnabled)
        XCTAssertTrue(element(app, AccessibilityID.homePhone).isEnabled)

        // S-3: four cakes.
        element(app, AccessibilityID.homeProducts).tap()
        XCTAssertTrue(element(app, AccessibilityID.productsList).waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(element(app, AccessibilityID.productCard(Self.firstProductID)).exists)
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "products.card."))
        XCTAssertEqual(cards.count, 4)

        // S-4: the first cake.
        element(app, AccessibilityID.productCard(Self.firstProductID)).tap()
        XCTAssertTrue(element(app, AccessibilityID.detailName).waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(element(app, AccessibilityID.detailName).label, "Bánh chuối")
        XCTAssertEqual(element(app, AccessibilityID.detailPrice).label, "35.000 ₫/cái")

        // S-5 stub.
        element(app, AccessibilityID.detailOrder).tap()
        let step = element(app, AccessibilityID.orderStep)
        XCTAssertTrue(step.waitForExistence(timeout: Self.timeout))
        XCTAssertEqual(step.label, "Bước 1/4")

        // Back to the list, nothing lost.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, AccessibilityID.productsList).waitForExistence(timeout: Self.timeout))
    }

    @MainActor
    func testHomeShowsTheErrorStateWithRetryAndDisabledActionsWithoutData() throws {
        let app = launch(stub: LaunchArgument.stubModeUnavailable)

        XCTAssertTrue(element(app, AccessibilityID.errorState).waitForExistence(timeout: Self.timeout))
        XCTAssertTrue(element(app, AccessibilityID.errorRetry).exists)
        XCTAssertFalse(element(app, AccessibilityID.homeOrder).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.homeProducts).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.homeZalo).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.homePhone).isEnabled)
    }
}
