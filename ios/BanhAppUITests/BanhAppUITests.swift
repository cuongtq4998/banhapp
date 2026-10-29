import XCTest

/// Runs the app against the in-process stub backend of debug builds (`-BanhStubBackend`), so the tests
/// need no network and see the same four fake cakes as `contracts/fixtures/catalog-ok.json`.
final class BanhAppUITests: BanhUITestCase {
    @MainActor
    func testMainFlowFromLaunchToTheFirstOrderStep() throws {
        let app = launch()

        // S-1 shows for 1 to 2 s, shorter than the test's first query can be relied on to catch, so
        // the launch screen is covered by the LaunchGate unit tests; the flow starts at S-2.
        let shopName = waitFor(app, AccessibilityID.homeShopName)
        XCTAssertEqual(shopName.label, "Tiệm Bánh An Nhiên")
        XCTAssertEqual(element(app, AccessibilityID.homeGreeting).label, "Bánh làm thủ công, giao tận nơi.")
        XCTAssertTrue(element(app, AccessibilityID.homeZalo).isEnabled)
        XCTAssertTrue(element(app, AccessibilityID.homePhone).isEnabled)

        // S-3: four cakes.
        tap(app, AccessibilityID.homeProducts)
        waitFor(app, AccessibilityID.productsList)
        XCTAssertTrue(element(app, AccessibilityID.productCard(Fake.banana)).exists)
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "products.card."))
        XCTAssertEqual(cards.count, 4)

        // S-4: the first cake.
        tap(app, AccessibilityID.productCard(Fake.banana))
        XCTAssertEqual(waitFor(app, AccessibilityID.detailName).label, "Bánh chuối")
        XCTAssertEqual(element(app, AccessibilityID.detailPrice).label, "35.000 ₫/cái")

        // S-5 with that cake at quantity 1 (AC-5).
        tap(app, AccessibilityID.detailOrder)
        XCTAssertEqual(waitFor(app, AccessibilityID.orderStep).label, "Bước 1/4")
        XCTAssertEqual(quantityText(app, Fake.banana), "Bánh chuối, số lượng 1")

        // Back to the detail, then the list: nothing lost.
        tap(app, AccessibilityID.backButton)
        waitFor(app, AccessibilityID.detailName)
        tap(app, AccessibilityID.backButton)
        waitFor(app, AccessibilityID.productsList)
    }

    @MainActor
    func testHomeShowsTheErrorStateWithRetryAndDisabledActionsWithoutData() throws {
        let app = launch(stub: LaunchArgument.stubModeUnavailable)

        waitFor(app, AccessibilityID.errorState)
        XCTAssertTrue(element(app, AccessibilityID.errorRetry).exists)
        XCTAssertFalse(element(app, AccessibilityID.homeOrder).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.homeProducts).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.homeZalo).isEnabled)
        XCTAssertFalse(element(app, AccessibilityID.homePhone).isEnabled)
    }
}
