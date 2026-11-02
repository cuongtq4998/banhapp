import XCTest

final class SignInUITests: AdminUITestCase {
    func testSignInWithEmailAndCodeLandsOnTheTodoList() {
        let app = launch(AdminLaunch.modeSignIn)
        XCTAssertFalse(element(app, AdminID.signInSend).isEnabled, "send is disabled while the field is empty")
        shot("S-A1-default")
        signIn(app)
        waitFor(app, AdminID.row("BT-7K3M9Q"))
        shot("S-A3-after-sign-in-staff")
    }

    func testInvalidEmailShowsTheFormatMessage() {
        let app = launch(AdminLaunch.modeSignIn)
        let field = waitFor(app, AdminID.signInEmail)
        field.tap()
        field.typeText("not-an-email")
        tap(app, AdminID.signInSend)
        waitFor(app, AdminID.signInError)
        shot("S-A1-error-email")
    }

    func testRateLimitedAddressShowsMinutes() {
        let app = launch(AdminLaunch.modeSignIn)
        let field = waitFor(app, AdminID.signInEmail)
        field.tap()
        field.typeText("limit@example.com")
        tap(app, AdminID.signInSend)
        waitFor(app, AdminID.signInError)
        shot("S-A1-error-rate-limit")
    }

    func testWrongCodeShowsErrorAndClearsTheField() {
        let app = launch(AdminLaunch.modeSignIn)
        let field = waitFor(app, AdminID.signInEmail)
        field.tap()
        field.typeText(AdminLaunch.fakeEmail)
        tap(app, AdminID.signInSend)
        waitFor(app, AdminID.codeField)
        shot("S-A2-default")
        app.typeText("111111")
        tap(app, AdminID.codeSubmit)
        waitFor(app, AdminID.codeError)
        shot("S-A2-error-wrong")
        XCTAssertFalse(element(app, AdminID.codeSubmit).isEnabled, "the cells are cleared, so sign-in is disabled")
        app.typeText("000000")
        tap(app, AdminID.codeSubmit)
        waitFor(app, AdminID.codeError)
        shot("S-A2-error-expired")
    }

    func testChangeEmailKeepsTheAddress() {
        let app = launch(AdminLaunch.modeSignIn)
        let field = waitFor(app, AdminID.signInEmail)
        field.tap()
        field.typeText(AdminLaunch.fakeEmail)
        tap(app, AdminID.signInSend)
        waitFor(app, AdminID.codeField)
        tap(app, AdminID.codeChangeEmail)
        XCTAssertEqual(waitFor(app, AdminID.signInEmail).value as? String, AdminLaunch.fakeEmail)
    }

    func testRevokedSessionShowsTheSessionEndedBanner() {
        let app = launch(AdminLaunch.modeRevoked)
        waitFor(app, AdminID.signInBanner)
        shot("S-A1-banner-session-ended")
    }

    func testOwnerSignInShowsTheTabBar() {
        let app = launch(AdminLaunch.modeSignInOwner)
        signIn(app, email: "owner@example.com")
        _ = tab(app, index: 0)
        _ = tab(app, index: 1)
        XCTAssertFalse(element(app, AdminID.ordersAccount).exists, "the owner has no account button on the list")
    }
}
