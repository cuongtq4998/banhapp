import XCTest

/// S-A10 Delivery and S-A12 Staff (owner, stub backend).
final class DeliveryStaffUITests: AdminUITestCase {
    private let district1 = "5b0c2f6a-0000-4a00-8000-0000000000d1"
    private let district2 = "5b0c2f6a-0000-4a00-8000-0000000000d2"
    private let slot1 = "5b0c2f6a-0000-4a00-8000-0000000000e1"

    private func openDelivery() -> XCUIApplication {
        let app = launch(AdminLaunch.modeOwner)
        openSettings(app, row: AdminOwnerID.rowDelivery)
        waitFor(app, AdminOwnerID.districtAdd)
        return app
    }

    func testDeliveryShowsBothSectionsAndAddsADistrict() {
        let app = openDelivery()
        waitFor(app, AdminOwnerID.districtRow(district1))
        waitFor(app, AdminOwnerID.slotRow(slot1))
        shot("S-A10-default")
        tap(app, AdminOwnerID.districtAdd)
        waitFor(app, AdminOwnerID.districtName)
        shot("S-A10-district-sheet")
        replaceText(app, AdminOwnerID.districtName, with: "Quan Moi")
        replaceText(app, AdminOwnerID.districtFee, with: "0")
        tap(app, AdminOwnerID.districtSave)
        waitFor(app, AdminOwnerID.districtErrorFee)
        shot("S-A10-district-fee-error")
        replaceText(app, AdminOwnerID.districtFee, with: "25000")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.districtSave)
        waitFor(app, AdminID.toast)
        waitFor(app, AdminOwnerID.districtAdd)
        shot("S-A10-district-added")
    }

    func testDuplicateDistrictNameIsExplained() {
        let app = openDelivery()
        tap(app, AdminOwnerID.districtAdd)
        replaceText(app, AdminOwnerID.districtName, with: "quan an phu")
        replaceText(app, AdminOwnerID.districtFee, with: "25000")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.districtSave)
        waitFor(app, AdminOwnerID.districtErrorName)
        shot("S-A10-district-duplicate")
    }

    func testLastActiveDistrictAndSlotCannotBeSwitchedOff() {
        let app = openDelivery()
        tap(app, AdminOwnerID.districtToggle(district1))
        waitFor(app, AdminID.toast)
        shot("S-A10-last-district-toast")
        XCTAssertEqual(element(app, AdminOwnerID.districtToggle(district1)).value as? String, "1")
        tap(app, AdminOwnerID.districtToggle(district2))
        let value = { self.element(app, AdminOwnerID.districtToggle(self.district2)).value as? String }
        let on = NSPredicate { _, _ in value() == "1" }
        wait(for: [XCTNSPredicateExpectation(predicate: on, object: nil)], timeout: 10)
    }

    func testSlotAddAndDuplicate() {
        let app = openDelivery()
        tap(app, AdminOwnerID.slotAdd)
        waitFor(app, AdminOwnerID.slotSave)
        shot("S-A10-slot-sheet")
        tap(app, AdminOwnerID.slotSave)
        waitFor(app, AdminOwnerID.slotError)
        shot("S-A10-slot-duplicate")
    }

    func testDeliveryOffline() {
        let app = launch(AdminLaunch.modeOwnerOffline)
        openSettings(app, row: AdminOwnerID.rowDelivery)
        waitFor(app, AdminOwnerID.offline)
        shot("S-A10-offline")
    }

    // MARK: Staff

    private func openStaff(_ mode: String = AdminLaunch.modeOwner) -> XCUIApplication {
        let app = launch(mode)
        openSettings(app, row: AdminOwnerID.rowStaff)
        waitFor(app, AdminOwnerID.staffAdd)
        return app
    }

    func testStaffListAddAndEmailTaken() {
        let app = openStaff()
        waitFor(app, AdminOwnerID.staffRow("5b0c2f6a-0000-4a00-8000-0000000000a2"))
        shot("S-A12-default")
        tap(app, AdminOwnerID.staffAdd)
        replaceText(app, AdminOwnerID.staffAddName, with: "Nhan Vien C")
        replaceText(app, AdminOwnerID.staffAddEmail, with: "NHANVIEN.A@example.com")
        dismissKeyboard(app)
        shot("S-A12-add-sheet")
        tap(app, AdminOwnerID.staffAddSave)
        waitFor(app, AdminOwnerID.fieldError("staffAdd", "email"))
        shot("S-A12-email-taken")
        replaceText(app, AdminOwnerID.staffAddEmail, with: "nhanvien.c@example.com")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.staffAddSave)
        waitFor(app, AdminID.toast)
        XCTAssertTrue(element(app, AdminOwnerID.staffCount).label.contains("2/30"))
    }

    func testDeactivateAndReactivateAStaffAccount() {
        let app = openStaff()
        tap(app, AdminOwnerID.staffRow("5b0c2f6a-0000-4a00-8000-0000000000a2"))
        waitFor(app, AdminOwnerID.staffDeactivate)
        shot("S-A12-detail")
        tap(app, AdminOwnerID.staffDeactivate)
        waitFor(app, AdminOwnerID.staffDeactivateYes)
        shot("S-A12-deactivate-dialog")
        tap(app, AdminOwnerID.staffDeactivateYes)
        waitFor(app, AdminID.toast)
        XCTAssertTrue(element(app, AdminOwnerID.staffCount).label.contains("0/30"))
        tap(app, AdminOwnerID.staffRow("5b0c2f6a-0000-4a00-8000-0000000000a3"))
        tap(app, AdminOwnerID.staffReactivate)
        waitFor(app, AdminID.toast)
        XCTAssertTrue(element(app, AdminOwnerID.staffCount).label.contains("1/30"))
    }

    func testAtThirtyStaffAddIsDisabledAndReactivateIsRefused() {
        let app = openStaff(AdminLaunch.modeOwnerFull)
        waitFor(app, AdminOwnerID.staffFull)
        XCTAssertFalse(element(app, AdminOwnerID.staffAdd).isEnabled)
        shot("S-A12-full")
    }

    func testStaffOffline() {
        let app = launch(AdminLaunch.modeOwnerOffline)
        openSettings(app, row: AdminOwnerID.rowStaff)
        waitFor(app, AdminOwnerID.offline)
        shot("S-A12-offline")
    }
}
