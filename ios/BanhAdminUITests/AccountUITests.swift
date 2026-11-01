import XCTest

final class AccountUITests: AdminUITestCase {
    func testStaffAccountSheetSignsOutOtherPhonesAndThisOne() {
        let app = launch(AdminLaunch.modeStaff)
        tap(app, AdminID.ordersAccount)
        waitFor(app, AdminID.accountName)
        shot("S-A13-default")
        tap(app, AdminID.accountSignOutOthers)
        waitFor(app, AdminID.accountSignOutOthersYes)
        shot("S-A13-dialog-others")
        tap(app, AdminID.accountSignOutOthersYes)
        waitFor(app, AdminID.toast)
        shot("S-A13-others-done-toast")
        tap(app, AdminID.accountSignOut)
        tap(app, AdminID.accountSignOutYes)
        waitFor(app, AdminID.signInEmail)
        XCTAssertFalse(element(app, AdminID.ordersTitle).exists, "no order data stays after sign-out")
    }

    func testOwnerSignsOutFromSettings() {
        let app = launch(AdminLaunch.modeOwner)
        tab(app, index: 1).tap()
        tap(app, AdminID.settingsSignOutOthers)
        waitFor(app, AdminID.settingsSignOutOthersYes)
        tap(app, AdminID.settingsSignOutOthersYes)
        waitFor(app, AdminID.toast)
        tap(app, AdminID.settingsSignOut)
        shot("S-A6-dialog-sign-out")
        tap(app, AdminID.settingsSignOutYes)
        waitFor(app, AdminID.signInEmail)
    }
}
