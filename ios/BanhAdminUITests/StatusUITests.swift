import XCTest

final class StatusUITests: AdminUITestCase {
    func testDetailShowsCustomerDeliveryCakesAndActions() {
        let app = launch(AdminLaunch.modeStaff)
        waitFor(app, AdminID.row("BT-7K3M9Q"))
        open(app, "BT-7K3M9Q")
        waitFor(app, AdminID.detailStatus)
        waitFor(app, AdminID.detailDue)
        waitFor(app, AdminID.detailCall)
        waitFor(app, AdminID.detailZalo)
        waitFor(app, AdminID.detailNote)
        waitFor(app, AdminID.detailLastChanged)
        waitFor(app, AdminID.detailConfirm)
        shot("S-A4-new")
        app.swipeUp()
        shot("S-A4-new-scrolled")
    }

    func testConfirmThenCompleteWithDialog() {
        let app = launch(AdminLaunch.modeStaff)
        open(app, "BT-9D6R3T")
        tap(app, AdminID.detailConfirm)
        waitFor(app, AdminID.toast)
        waitFor(app, AdminID.detailComplete)
        absent(app, AdminID.detailConfirm)
        shot("S-A4-confirmed-toast")
        tap(app, AdminID.detailComplete)
        waitFor(app, AdminID.detailCompleteYes)
        shot("S-A4-complete-dialog")
        tap(app, AdminID.detailCompleteBack)
        waitFor(app, AdminID.detailComplete)
        tap(app, AdminID.detailComplete)
        tap(app, AdminID.detailCompleteYes)
        absent(app, AdminID.detailComplete)
        XCTAssertFalse(element(app, AdminID.detailCancel).exists, "completed orders have no action bar")
        shot("S-A4-completed")
    }

    func testCancelNeedsAReasonAndShowsItAfterwards() {
        let app = launch(AdminLaunch.modeStaff)
        open(app, "BT-9D6R3T")
        tap(app, AdminID.detailCancel)
        waitFor(app, AdminID.cancelConfirm)
        XCTAssertFalse(element(app, AdminID.cancelConfirm).isEnabled, "nothing is preselected")
        shot("S-A5-default")
        tap(app, AdminID.cancelNoContact)
        XCTAssertTrue(element(app, AdminID.cancelConfirm).isEnabled)
        shot("S-A5-reason-chosen")
        tap(app, AdminID.cancelConfirm)
        waitFor(app, AdminID.detailReason)
        absent(app, AdminID.detailCancel)
        shot("S-A4-cancelled")
    }

    func testConflictShowsTheCurrentStatusWithAWarning() {
        let app = launch(AdminLaunch.modeConflict)
        open(app, "BT-7K3M9Q")
        tap(app, AdminID.detailConfirm)
        waitFor(app, AdminID.detailConflict)
        waitFor(app, AdminID.detailComplete)
        shot("S-A4-conflict")
    }

    func testUnknownOrderShowsTheGoneState() {
        let app = launch(AdminLaunch.modeGone)
        tap(app, AdminID.row("BT-7K3M9Q"))
        waitFor(app, AdminID.detailGone)
        shot("S-A4-gone")
        tap(app, AdminID.detailRetry)
        waitFor(app, AdminID.ordersTitle)
    }

    func testListRefreshesAfterAStatusChange() {
        let app = launch(AdminLaunch.modeStaff)
        open(app, "BT-7K3M9Q")
        tap(app, AdminID.detailCancel)
        tap(app, AdminID.cancelSpam)
        tap(app, AdminID.cancelConfirm)
        waitFor(app, AdminID.detailReason)
        tap(app, AdminID.navBack)
        absent(app, AdminID.row("BT-7K3M9Q"))
    }
}
