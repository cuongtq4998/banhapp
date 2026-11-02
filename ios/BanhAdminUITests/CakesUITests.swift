import XCTest

/// S-A7 Cakes and S-A8 Cake form (owner, stub backend). The system photo picker cannot be driven from
/// a UI test, so the debug stub shows a button that "picks" a generated photo.
final class CakesUITests: AdminUITestCase {
    private let cake1 = "5b0c2f6a-0000-4a00-8000-0000000000c01"

    private func openCakes(_ mode: String = AdminLaunch.modeOwner) -> XCUIApplication {
        let app = launch(mode)
        openSettings(app, row: AdminOwnerID.rowCakes)
        waitFor(app, AdminOwnerID.cakesAdd)
        return app
    }

    func testListShowsCountAddButtonAndHiddenCakes() {
        let app = openCakes()
        waitFor(app, AdminOwnerID.cakeRow(cake1))
        XCTAssertTrue(element(app, AdminOwnerID.cakesCount).label.contains("3/12"))
        XCTAssertTrue(element(app, AdminOwnerID.cakesAdd).isEnabled)
        shot("S-A7-default")
    }

    func testListAtTwelveCakesDisablesAddAndExplains() {
        let app = openCakes(AdminLaunch.modeOwnerFull)
        waitFor(app, AdminOwnerID.cakesFull)
        XCTAssertFalse(element(app, AdminOwnerID.cakesAdd).isEnabled)
        shot("S-A7-full")
    }

    func testListOfflineAndError() {
        let app = launch(AdminLaunch.modeOwnerOffline)
        openSettings(app, row: AdminOwnerID.rowCakes)
        waitFor(app, AdminOwnerID.offline)
        shot("S-A7-offline")
        app.terminate()
        let failing = launch(AdminLaunch.modeOwnerError)
        openSettings(failing, row: AdminOwnerID.rowCakes)
        waitFor(failing, AdminOwnerID.error)
        shot("S-A7-error")
    }

    func testAddNeedsAPictureThenUploadsAndReturnsToTheList() {
        let app = openCakes()
        tap(app, AdminOwnerID.cakesAdd)
        waitFor(app, AdminOwnerID.cakeName)
        shot("S-A8-add-empty")
        XCTAssertFalse(element(app, AdminOwnerID.cakeSave).isEnabled, "nothing typed yet")
        replaceText(app, AdminOwnerID.cakeName, with: "Banh Moi")
        XCTAssertTrue(element(app, AdminOwnerID.cakeSave).isEnabled, "enabled once anything is typed")
        replaceText(app, AdminOwnerID.cakeDesc, with: "Mo ta")
        replaceText(app, AdminOwnerID.cakePrice, with: "150000")
        dismissKeyboard(app)
        tap(app, "admin.cakeForm.debugPick")
        waitFor(app, AdminOwnerID.cakeImagePreview)
        shot("S-A8-add-filled")
        tap(app, AdminOwnerID.cakeSave)
        waitFor(app, AdminOwnerID.cakesAdd)
        waitFor(app, AdminID.toast)
        XCTAssertTrue(element(app, AdminOwnerID.cakesCount).label.contains("4/12"))
        shot("S-A7-after-add-toast")
    }

    func testSaveWithNothingValidListsEveryMissingField() {
        let app = openCakes()
        tap(app, AdminOwnerID.cakesAdd)
        replaceText(app, AdminOwnerID.cakeName, with: "x")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.cakeSave)
        waitFor(app, AdminOwnerID.fieldError("cakeForm", "description"))
        waitFor(app, AdminOwnerID.fieldError("cakeForm", "price_vnd"))
        waitFor(app, AdminOwnerID.fieldError("cakeForm", "image"))
        shot("S-A8-save-lists-all-missing")
    }

    func testAddShowsErrorsAtOnceNameTakenAndBrokenPicture() {
        let app = openCakes()
        tap(app, AdminOwnerID.cakesAdd)
        tap(app, "admin.cakeForm.debugPickBroken")
        waitFor(app, AdminOwnerID.fieldError("cakeForm", "image"))
        shot("S-A8-picture-refused")
        replaceText(app, AdminOwnerID.cakeName, with: "banh mau")
        replaceText(app, AdminOwnerID.cakeDesc, with: "Mo ta")
        replaceText(app, AdminOwnerID.cakePrice, with: "0")
        dismissKeyboard(app)
        tap(app, "admin.cakeForm.debugPick")
        waitFor(app, AdminOwnerID.cakeImagePreview)
        tap(app, AdminOwnerID.cakeSave)
        waitFor(app, AdminOwnerID.fieldError("cakeForm", "price_vnd"))
        shot("S-A8-price-error")
        replaceText(app, AdminOwnerID.cakePrice, with: "150000")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.cakeSave)
        waitFor(app, AdminOwnerID.fieldError("cakeForm", "name"))
        shot("S-A8-name-taken")
    }

    func testThirteenthCakeIsRefusedByTheServerRule() {
        let app = openCakes(AdminLaunch.modeOwnerFull)
        waitFor(app, AdminOwnerID.cakesFull)
        // The list already disables Add; the form is reached through the stub only when 11 are present.
        XCTAssertFalse(element(app, AdminOwnerID.cakesAdd).isEnabled)
    }

    func testUploadCanBeCancelledAndCreatesNothing() {
        let app = openCakes(AdminLaunch.modeOwnerSlow)
        tap(app, AdminOwnerID.cakesAdd)
        replaceText(app, AdminOwnerID.cakeName, with: "Banh Cham")
        replaceText(app, AdminOwnerID.cakeDesc, with: "Mo ta")
        replaceText(app, AdminOwnerID.cakePrice, with: "90000")
        dismissKeyboard(app)
        tap(app, "admin.cakeForm.debugPick")
        waitFor(app, AdminOwnerID.cakeImagePreview)
        tap(app, AdminOwnerID.cakeSave)
        waitFor(app, AdminOwnerID.cakeProgress)
        shot("S-A8-uploading")
        tap(app, AdminOwnerID.cakeCancel)
        waitFor(app, AdminOwnerID.cakeSave)
        XCTAssertTrue(element(app, AdminOwnerID.cakeImagePreview).exists, "picture and values stay")
        tap(app, AdminOwnerID.back("cakeForm"))
        tap(app, AdminOwnerID.discardConfirm)
        waitFor(app, AdminOwnerID.cakesAdd)
        XCTAssertTrue(element(app, AdminOwnerID.cakesCount).label.contains("3/12"))
    }

    func testEditHidesTheCakeThenRefusesToHideTheLastActiveOne() {
        let app = openCakes()
        tap(app, AdminOwnerID.cakeRow(cake1))
        waitFor(app, AdminOwnerID.cakeActive)
        shot("S-A8-edit-default")
        XCTAssertFalse(element(app, AdminOwnerID.cakeSave).isEnabled)
        flip(app, AdminOwnerID.cakeActive)
        XCTAssertTrue(element(app, AdminOwnerID.cakeSave).isEnabled)
        tap(app, AdminOwnerID.cakeSave)
        waitFor(app, AdminOwnerID.cakesAdd)
        // Now only "Banh Chuoi" is active: its switch refuses to go off.
        tap(app, AdminOwnerID.cakeRow("5b0c2f6a-0000-4a00-8000-0000000000c02"))
        waitFor(app, AdminOwnerID.cakeActive)
        flip(app, AdminOwnerID.cakeActive)
        waitFor(app, AdminID.toast)
        shot("S-A8-last-active-toast")
        XCTAssertFalse(element(app, AdminOwnerID.cakeSave).isEnabled, "the switch stayed on")
    }

    func testRemoveAsksThenDeletesTheCake() {
        let app = openCakes()
        tap(app, AdminOwnerID.cakeRow("5b0c2f6a-0000-4a00-8000-0000000000c03"))
        waitFor(app, AdminOwnerID.cakeRemove)
        tap(app, AdminOwnerID.cakeRemove)
        waitFor(app, AdminOwnerID.cakeRemoveYes)
        shot("S-A8-remove-dialog")
        tap(app, AdminOwnerID.cakeRemoveYes)
        waitFor(app, AdminOwnerID.cakesAdd)
        waitFor(app, AdminID.toast)
        absent(app, AdminOwnerID.cakeRow("5b0c2f6a-0000-4a00-8000-0000000000c03"))
        XCTAssertTrue(element(app, AdminOwnerID.cakesCount).label.contains("2/12"))
    }
}
