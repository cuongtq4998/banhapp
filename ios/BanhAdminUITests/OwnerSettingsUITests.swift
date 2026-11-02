import XCTest

/// S-A6 Settings, S-A9 Ordering, S-A11 Shop info (owner, stub backend).
final class OwnerSettingsUITests: AdminUITestCase {
    func testSettingsShowsFiveRowsWithValuesAndNote() {
        let app = launch(AdminLaunch.modeOwner)
        openSettings(app)
        for id in [AdminOwnerID.rowCakes, AdminOwnerID.rowRules, AdminOwnerID.rowDelivery, AdminOwnerID.rowShop, AdminOwnerID.rowStaff] {
            waitFor(app, id)
        }
        waitFor(app, AdminOwnerID.rowValue(AdminOwnerID.rowStaff))
        XCTAssertEqual(element(app, AdminOwnerID.rowValue(AdminOwnerID.rowCakes)).label, "3/12")
        XCTAssertEqual(element(app, AdminOwnerID.rowValue(AdminOwnerID.rowStaff)).label, "1/30")
        waitFor(app, AdminID.settingsSignOut)
        XCTAssertEqual(element(app, AdminID.accountEmail).label, "chu.tiem@example.com", "the account card shows who is signed in")
        XCTAssertEqual(element(app, AdminID.accountName).label, "Chu Tiem")
        shot("S-A6-default")
    }

    func testStaffNeverSeesTheSettingsTab() {
        let app = launch(AdminLaunch.modeStaff)
        waitFor(app, AdminID.ordersTitle)
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testRulesValidationShowsEveryErrorAtOnce() {
        let app = launch(AdminLaunch.modeOwner)
        openSettings(app, row: AdminOwnerID.rowRules)
        waitFor(app, AdminOwnerID.rulesLimit)
        shot("S-A9-default")
        XCTAssertFalse(element(app, AdminOwnerID.rulesSave).isEnabled, "nothing changed yet")
        replaceText(app, AdminOwnerID.rulesLimit, with: "0")
        replaceText(app, AdminOwnerID.rulesLead, with: "15")
        replaceText(app, AdminOwnerID.rulesMin, with: "30")
        tap(app, AdminOwnerID.rulesSave)
        waitFor(app, AdminOwnerID.fieldError("rules", "daily_limit"))
        waitFor(app, AdminOwnerID.fieldError("rules", "lead_days"))
        waitFor(app, AdminOwnerID.fieldError("rules", "min_qty"))
        shot("S-A9-errors")
    }

    func testLoweringTheLimitWarnsThenSaves() {
        let app = launch(AdminLaunch.modeOwner)
        openSettings(app, row: AdminOwnerID.rowRules)
        replaceText(app, AdminOwnerID.rulesLimit, with: "40")
        tap(app, AdminOwnerID.rulesSave)
        waitFor(app, AdminOwnerID.rulesWarnConfirm)
        shot("S-A9-warning")
        tap(app, AdminOwnerID.rulesWarnBack)
        absent(app, AdminOwnerID.rulesWarnConfirm)
        tap(app, AdminOwnerID.rulesSave)
        tap(app, AdminOwnerID.rulesWarnConfirm)
        // The list returned by the save is the one just confirmed, so it is not shown a second time.
        waitFor(app, AdminOwnerID.rowCakes)
        waitFor(app, AdminID.toast)
        XCTAssertTrue(element(app, AdminOwnerID.rowValue(AdminOwnerID.rowRules)).label.contains("40"))
        shot("S-A6-after-save-toast")
    }

    func testRulesLoadErrorOffersRetry() {
        let app = launch(AdminLaunch.modeOwnerOffline)
        openSettings(app, row: AdminOwnerID.rowRules)
        waitFor(app, AdminOwnerID.offline)
        shot("S-A9-offline")
        waitFor(app, AdminOwnerID.retry)
    }

    func testRulesLeavingWithChangesAsksToDiscard() {
        let app = launch(AdminLaunch.modeOwner)
        openSettings(app, row: AdminOwnerID.rowRules)
        replaceText(app, AdminOwnerID.rulesLead, with: "5")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.back("rules"))
        waitFor(app, AdminOwnerID.discardKeep)
        shot("S-A9-discard-dialog")
        tap(app, AdminOwnerID.discardKeep)
        tap(app, AdminOwnerID.back("rules"))
        tap(app, AdminOwnerID.discardConfirm)
        waitFor(app, AdminOwnerID.rowCakes)
    }

    func testShopInfoValidatesAndSaves() {
        let app = launch(AdminLaunch.modeOwner)
        openSettings(app, row: AdminOwnerID.rowShop)
        waitFor(app, AdminOwnerID.shopName)
        shot("S-A11-default")
        replaceText(app, AdminOwnerID.shopName, with: "")
        replaceText(app, AdminOwnerID.shopPhone, with: "123")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.shopSave)
        waitFor(app, AdminOwnerID.fieldError("shop", "name"))
        waitFor(app, AdminOwnerID.fieldError("shop", "phone_contact"))
        shot("S-A11-errors")
        replaceText(app, AdminOwnerID.shopName, with: "Tiem Moi")
        replaceText(app, AdminOwnerID.shopPhone, with: "0900111222")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.shopSave)
        waitFor(app, AdminOwnerID.rowCakes)
        waitFor(app, AdminID.toast)
        XCTAssertEqual(element(app, AdminOwnerID.rowValue(AdminOwnerID.rowShop)).label, "Tiem Moi")
    }

    func testServerErrorOnSaveKeepsTheForm() {
        let app = launch(AdminLaunch.modeOwnerError)
        openSettings(app, row: AdminOwnerID.rowShop)
        waitFor(app, AdminOwnerID.error)
        shot("S-A11-error")
    }
}
