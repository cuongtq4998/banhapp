import XCTest

/// Notification handling (FR-25, FR-26): the stub simulates the arrival and the tap.
final class PushUITests: AdminUITestCase {
    private func launch(_ mode: String, push: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-\(AdminLaunch.stub)", mode, "-\(AdminPushLaunch.key)", push]
        app.launch()
        return app
    }

    func testForegroundNotificationShowsAToastThatOpensTheOrder() {
        let app = launch(AdminLaunch.modeStaff, push: "foreground:BT-9D6R3T")
        waitFor(app, AdminID.ordersTitle)
        let toast = waitFor(app, AdminOwnerID.notifForeground)
        XCTAssertTrue(toast.label.contains("BT-9D6R3T"))
        shot("A-NOTIF-foreground-toast")
        toast.tap()
        waitFor(app, AdminID.detailCode)
        tap(app, AdminID.navBack)
        waitFor(app, AdminID.ordersTitle)
    }

    func testTappedNotificationOpensTheOrderAfterLaunch() {
        let app = launch(AdminLaunch.modeStaff, push: "tap:BT-7K3M9Q")
        let code = waitFor(app, AdminID.detailCode)
        XCTAssertTrue(code.label.contains("BT-7K3M9Q"))
        shot("A-NOTIF-tap-opens-detail")
        tap(app, AdminID.navBack)
        waitFor(app, AdminID.ordersTitle)
    }

    func testTappedNotificationWhileSignedOutOpensTheOrderAfterSignIn() {
        let app = launch(AdminLaunch.modeSignIn, push: "tap:BT-7K3M9Q")
        waitFor(app, AdminID.signInEmail)
        signInKeepingDetail(app)
        waitFor(app, AdminID.detailCode)
    }

    func testUnknownOrderFromANotificationShowsTheGoneState() {
        let app = launch(AdminLaunch.modeStaff, push: "tap:BT-000000")
        waitFor(app, AdminID.detailGone)
        shot("A-NOTIF-tap-order-gone")
    }

    /// Like `signIn`, but the orders list is not the first screen.
    private func signInKeepingDetail(_ app: XCUIApplication) {
        let field = waitFor(app, AdminID.signInEmail)
        field.tap()
        field.typeText(AdminLaunch.fakeEmail)
        tap(app, AdminID.signInSend)
        waitFor(app, AdminID.codeField)
        app.typeText(AdminLaunch.fakeCode)
        tap(app, AdminID.codeSubmit)
    }
}
