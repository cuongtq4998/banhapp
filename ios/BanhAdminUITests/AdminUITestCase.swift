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
            let row = element(app, AdminID.filterFinished)
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

    /// Owner stub: opens the Settings tab and one of its rows.
    func openSettings(_ app: XCUIApplication, row: String? = nil) {
        tab(app, index: 1).tap()
        waitFor(app, AdminOwnerID.rowCakes)
        if let row { tap(app, row) }
    }

    /// Replaces the text of a field: focus, delete what is there, type the new text.
    func replaceText(_ app: XCUIApplication, _ identifier: String, with text: String) {
        let field = waitFor(app, identifier)
        // A field under the keyboard cannot be tapped: close the keyboard first, the form scrolls back.
        if app.keyboards.count > 0, field.frame.maxY > app.keyboards.firstMatch.frame.minY - 20 {
            dismissKeyboard(app)
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 0"), object: app.keyboards)
            _ = XCTWaiter().wait(for: [gone], timeout: 5)
        }
        field.tap()
        Thread.sleep(forTimeInterval: 0.6)
        // Typing goes through the app: it reaches whatever has the focus (a multiline field too).
        let current = (field.value as? String) ?? ""
        if !current.isEmpty, current != "Optional" {
            app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        if !text.isEmpty { app.typeText(text) }
    }

    func dismissKeyboard(_ app: XCUIApplication) {
        if app.keyboards.count > 0 { app.swipeDown() }
    }

    /// Flips a labelled switch: the centre of the row is the label, the switch is at the right edge.
    func flip(_ app: XCUIApplication, _ identifier: String) {
        let toggle = app.switches[identifier]
        var scrolls = 0
        while toggle.waitForExistence(timeout: 5), !toggle.isHittable, scrolls < 4 {
            app.swipeUp()
            scrolls += 1
        }
        if toggle.exists { toggle.tap() } else {
            waitFor(app, identifier).coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
    }
}
