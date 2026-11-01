import XCTest

/// Shared helpers of the admin UI tests: launch against the in-process stub backend, find elements by
/// accessibility identifier only (never by visible text), and save a screenshot of each screen state.
class AdminUITestCase: XCTestCase {
    static let timeout: TimeInterval = 10
    /// Set with `TEST_RUNNER_ADMIN_SHOTS_DIR=<folder>` to also write PNG files; always attached to the result.
    private static let shotsDirectory = ProcessInfo.processInfo.environment["ADMIN_SHOTS_DIR"]

    override func setUpWithError() throws { continueAfterFailure = false }

    func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-\(AdminLaunch.stub)", mode]
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

    /// Taps a filter chip, scrolling the chip row sideways until the chip is inside the screen.
    func tapChip(_ app: XCUIApplication, _ identifier: String) {
        let chip = waitFor(app, identifier)
        let screen = app.windows.firstMatch.frame
        var attempts = 0
        while !screen.contains(chip.frame) && attempts < 4 {
            let row = element(app, AdminID.filterCompleted)
            if chip.frame.maxX > screen.maxX { row.swipeLeft() } else { row.swipeRight() }
            attempts += 1
        }
        chip.tap()
    }

    /// The native tab bar does not pass identifiers to its buttons, so tabs are found by position.
    func tab(_ app: XCUIApplication, index: Int) -> XCUIElement {
        let button = app.tabBars.firstMatch.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: Self.timeout), "tab \(index) did not appear")
        return button
    }

    func absent(_ app: XCUIApplication, _ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element(app, identifier))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: Self.timeout), .completed, "\(identifier) is still there", file: file, line: line)
    }

    func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = Self.shotsDirectory {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appending(path: "\(name).png"))
        }
    }

    /// Signs in with the fake code and lands on the list.
    func signIn(_ app: XCUIApplication, email: String = AdminLaunch.fakeEmail) {
        let field = waitFor(app, AdminID.signInEmail)
        field.tap()
        field.typeText(email)
        tap(app, AdminID.signInSend)
        waitFor(app, AdminID.codeField)
        app.typeText(AdminLaunch.fakeCode)
        tap(app, AdminID.codeSubmit)
        waitFor(app, AdminID.ordersTitle)
    }

    func open(_ app: XCUIApplication, _ code: String) {
        tap(app, AdminID.row(code))
        waitFor(app, AdminID.detailCode)
    }
}
