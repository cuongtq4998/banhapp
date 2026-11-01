import XCTest

/// Base of the live operating-flow tests: the admin app (real backend, no stub), numbered screenshots in
/// `E2E_SHOTS_DIR` and the shared state file. The admin app is launched once and reused by every method, so
/// the owner's session survives between methods (each sign-in costs one of three code requests an hour).
class LiveCase: AdminUITestCase {
    private static var shotNumber = 0
    private static var adminApp: XCUIApplication?
    /// Access token of the owner's helper session (second sign-in), shared by the methods.
    nonisolated(unsafe) static var ownerToken: String?
    var state = LiveState.load()

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = true // keep going after a failed check: a run costs sign-in codes
        try Live.requireEnabled()
        state = LiveState.load()
    }

    override func tearDown() {
        state.save()
        super.tearDown()
    }

    /// Admin app on the real backend. `fresh` starts it again (signed-in state is restored from the keychain).
    func admin(fresh: Bool = false) -> XCUIApplication {
        if let app = Self.adminApp, !fresh {
            app.activate()
            return app
        }
        let app = XCUIApplication(bundleIdentifier: Live.adminBundle)
        app.launchArguments = []
        app.launch()
        Self.adminApp = app
        return app
    }

    /// Saves `NN-name.png` to the evidence folder (and attaches it to the result).
    func evidence(_ name: String, app: XCUIApplication? = nil) {
        Self.shotNumber += 1
        let screenshot = XCUIScreen.main.screenshot()
        let file = String(format: "%02d-%@", Self.shotNumber, name)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = file
        attachment.lifetime = .keepAlways
        add(attachment)
        try? FileManager.default.createDirectory(at: Live.shotsDirectory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: Live.shotsDirectory.appending(path: "\(file).png"))
    }

    func note(_ text: String) { state.notes.append(text); state.save() }

    /// Signs in on the real backend: asks for the code, reads it from the backend log, types it.
    func signInLive(_ app: XCUIApplication, email: String) {
        let field = waitFor(app, AdminID.signInEmail)
        field.tap()
        field.typeText(email)
        evidence("signin-email", app: app)
        let offset = LiveLog.size
        tap(app, AdminID.signInSend)
        waitFor(app, AdminID.codeField)
        guard let code = LiveLog.code(after: offset) else { return XCTFail("no code in the backend log within 10 s") }
        app.typeText(code)
        evidence("signin-code", app: app)
        tap(app, AdminID.codeSubmit)
        waitFor(app, AdminID.ordersTitle)
    }

    func goBack(_ app: XCUIApplication) {
        let back = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'admin.' AND identifier ENDSWITH '.back'")).firstMatch
        if back.waitForExistence(timeout: 3) { back.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
    }

    /// Settings tab, even when an earlier step left a form open.
    func openSettingsTab(_ app: XCUIApplication, row: String? = nil) {
        var tries = 0
        while !app.tabBars.firstMatch.exists, tries < 3 {
            let back = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'admin.' AND identifier ENDSWITH '.back'")).firstMatch
            if back.exists { back.tap() } else if app.navigationBars.buttons.firstMatch.exists { app.navigationBars.buttons.firstMatch.tap() }
            let discard = element(app, AdminOwnerID.discardConfirm)
            if discard.waitForExistence(timeout: 1) { discard.tap() }
            tries += 1
        }
        openSettings(app, row: row)
    }

    func label(_ app: XCUIApplication, _ identifier: String) -> String {
        let found = waitFor(app, identifier)
        return [found.label, found.value as? String ?? ""].joined(separator: " ")
    }

    /// Opens the list filter "To do" and the order row, then waits for the detail.
    func openOrder(_ app: XCUIApplication, _ code: String) {
        let row = element(app, AdminID.row(code))
        if !row.waitForExistence(timeout: 6) { app.swipeDown() }
        open(app, code)
    }

    func backToList(_ app: XCUIApplication) {
        let back = element(app, AdminID.navBack)
        if back.exists { back.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
        waitFor(app, AdminID.ordersTitle)
    }
}
