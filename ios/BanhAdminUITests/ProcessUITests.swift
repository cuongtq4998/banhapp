import XCTest

/// The five-step order process against the stub server (api/09 10.13).
final class ProcessUITests: AdminUITestCase {
    private func process(_ app: XCUIApplication, _ code: String) {
        open(app, code)
        tap(app, AdminID.orderProcess)
        waitFor(app, AdminID.orderSchedule)
    }

    private func schedule(_ app: XCUIApplication) {
        tap(app, AdminID.orderSchedule)
        waitFor(app, AdminID.scheduleLimit)
        tap(app, AdminID.scheduleSave)
        waitFor(app, AdminID.orderStartDelivery)
    }

    private func startDelivery(_ app: XCUIApplication, fee: String) {
        tap(app, AdminID.orderStartDelivery)
        replaceText(app, AdminID.feeField, with: fee)
        tap(app, AdminID.feeConfirm)
        waitFor(app, AdminID.orderFinish)
    }

    func testFiveStepFlowEndsFinished() {
        let app = launch(AdminLaunch.modeStaff)
        waitFor(app, AdminID.row("BT-9D6R3T"))
        process(app, "BT-9D6R3T")
        waitFor(app, AdminID.stepper)
        waitFor(app, AdminID.step(5))
        schedule(app)
        waitFor(app, AdminID.orderExpectedDate)
        startDelivery(app, fee: "20000")
        tap(app, AdminID.orderFinish)
        tap(app, AdminID.detailCompleteYes)
        absent(app, AdminID.orderFinish)
        shot("process-finished")
    }

    func testCancelIsNotOfferedFromTheScheduledStepOn() {
        let app = launch(AdminLaunch.modeStaff)
        process(app, "BT-9D6R3T")
        waitFor(app, AdminID.detailCancel)
        schedule(app)
        waitFor(app, AdminID.orderCancelBlocked)
        absent(app, AdminID.detailCancel)
    }

    func testScheduleSheetNamesTheServerLimit() {
        let app = launch(AdminLaunch.modeStaff)
        process(app, "BT-9D6R3T")
        tap(app, AdminID.orderSchedule)
        waitFor(app, AdminID.schedulePicker)
        waitFor(app, AdminID.scheduleLimit)
        shot("process-schedule-sheet")
    }

    func testFeeZeroIsAccepted() {
        let app = launch(AdminLaunch.modeStaff)
        process(app, "BT-9D6R3T")
        schedule(app)
        startDelivery(app, fee: "0")
        waitFor(app, AdminID.orderTotalCollect)
    }

    func testFeeCorrectionIsRecordedInTheHistory() {
        let app = launch(AdminLaunch.modeStaff)
        process(app, "BT-9D6R3T")
        schedule(app)
        startDelivery(app, fee: "20000")
        tap(app, AdminID.orderFeeCorrect)
        replaceText(app, AdminID.feeFixField, with: "35000")
        tap(app, AdminID.feeFixSave)
        waitFor(app, AdminID.orderFeeHistory)
    }

    func testAmountToCollectIsHiddenBeforeTheFee() {
        let app = launch(AdminLaunch.modeStaff)
        process(app, "BT-9D6R3T")
        waitFor(app, AdminID.orderFee)
        absent(app, AdminID.orderTotalCollect)
        schedule(app)
        absent(app, AdminID.orderTotalCollect)
    }
}
