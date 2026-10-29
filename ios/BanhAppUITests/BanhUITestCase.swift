import XCTest

/// Shared helpers of the UI tests: launch against the in-process stub backend and find elements by
/// accessibility identifier only, never by visible text (UI document 9.1).
class BanhUITestCase: XCTestCase {
    static let timeout: TimeInterval = 10

    /// Ids of the fake shop (`contracts/fixtures/catalog-ok.json`).
    enum Fake {
        static let banana = "00000000-0000-4000-8000-000000000011"
        static let porkFat = "00000000-0000-4000-8000-000000000012"
        static let district5 = "00000000-0000-4000-8000-000000000023"
        static let district1 = "00000000-0000-4000-8000-000000000021"
        static let slotAfternoon = "00000000-0000-4000-8000-000000000033"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launch(stub mode: String = LaunchArgument.stubModeCatalog) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-\(LaunchArgument.stubBackend)", mode]
        app.launch()
        return app
    }

    func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @discardableResult
    func waitFor(_ app: XCUIApplication, _ identifier: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let found = element(app, identifier)
        XCTAssertTrue(found.waitForExistence(timeout: Self.timeout), "\(identifier) did not appear", file: file, line: line)
        return found
    }

    func tap(_ app: XCUIApplication, _ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(app, identifier, file: file, line: line).tap()
    }

    /// Home, then "Place order": the empty first step.
    func openOrderFlow(_ app: XCUIApplication) {
        tap(app, AccessibilityID.homeOrder)
        waitFor(app, AccessibilityID.orderStep)
    }

    func quantityText(_ app: XCUIApplication, _ productID: String) -> String {
        waitFor(app, AccessibilityID.qtyValue(productID)).label
    }

    func addCakes(_ app: XCUIApplication, _ productID: String, times: Int) {
        for _ in 0..<times { tap(app, AccessibilityID.qtyIncrease(productID)) }
    }

    /// S-5 with 2 bananas and 1 pork-fat cake (3 cakes), then Next.
    func chooseThreeCakes(_ app: XCUIApplication) {
        addCakes(app, Fake.banana, times: 2)
        addCakes(app, Fake.porkFat, times: 1)
        tap(app, AccessibilityID.orderNext)
    }

    /// S-6 with 2026-11-04 and the afternoon slot, then Next.
    func chooseDateAndSlot(_ app: XCUIApplication, date: String = "2026-11-04") {
        tap(app, AccessibilityID.dateCell(date))
        tap(app, AccessibilityID.slotChip(Fake.slotAfternoon))
        tap(app, AccessibilityID.orderNext)
    }

    /// S-7 filled with fake data and the district Quận 5 (fee 20.000), then Next.
    func fillRecipient(_ app: XCUIApplication, district: String = Fake.district5) {
        waitFor(app, AccessibilityID.fieldName).tap()
        app.typeText("Nguyen Van An")
        element(app, AccessibilityID.fieldPhone).tap()
        app.typeText("0912345678")
        element(app, AccessibilityID.fieldAddress).tap()
        app.typeText("12 Duong So 3")
        tap(app, AccessibilityID.fieldDistrict)
        tap(app, AccessibilityID.districtRow(district))
        tap(app, AccessibilityID.orderNext)
    }
}
