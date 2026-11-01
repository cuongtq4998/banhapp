import XCTest

final class OrdersUITests: AdminUITestCase {
    func testTodoListShowsDueMarksAndTheStaffBadge() {
        let app = launch(AdminLaunch.modeStaff)
        waitFor(app, AdminID.row("BT-7K3M9Q"))
        waitFor(app, AdminID.due("BT-7K3M9Q"))
        waitFor(app, AdminID.due("BT-4H8N2P"))
        XCTAssertFalse(element(app, AdminID.due("BT-9D6R3T")).exists)
        XCTAssertFalse(element(app, AdminID.row("BT-6F3J8M")).exists, "completed orders are not in To do")
        waitFor(app, AdminID.ordersBadge)
        waitFor(app, AdminID.ordersAccount)
        shot("S-A3-default-todo-staff")
    }

    func testStatusChipsAndDateMenu() {
        let app = launch(AdminLaunch.modeStaff)
        waitFor(app, AdminID.row("BT-7K3M9Q"))
        tap(app, AdminID.filterCompleted)
        waitFor(app, AdminID.row("BT-6F3J8M"))
        XCTAssertFalse(element(app, AdminID.row("BT-7K3M9Q")).exists)
        shot("S-A3-filter-completed")
        tapChip(app, AdminID.filterAll)
        waitFor(app, AdminID.row("BT-8B2K4N"))
        tapChip(app, AdminID.filterTodo)
        tapChip(app, AdminID.filterDate)
        shot("S-A3-date-menu")
        tap(app, AdminID.dateTomorrow)
        waitFor(app, AdminID.row("BT-9D6R3T"))
        XCTAssertFalse(element(app, AdminID.row("BT-7K3M9Q")).exists)
        shot("S-A3-filter-tomorrow")
    }

    func testSearchNeedsThreeCharacters() {
        let app = launch(AdminLaunch.modeStaff)
        waitFor(app, AdminID.row("BT-7K3M9Q"))
        tap(app, AdminID.ordersSearch)
        shot("S-A3-search-hint")
        app.typeText("le")
        waitFor(app, AdminID.ordersSearchMin)
        XCTAssertTrue(element(app, AdminID.row("BT-7K3M9Q")).exists, "two characters do not search")
        shot("S-A3-search-min")
        app.typeText(" v")
        waitFor(app, AdminID.row("BT-4H8N2P"))
        absent(app, AdminID.row("BT-7K3M9Q"))
        shot("S-A3-search-result")
        app.typeText("zzz")
        waitFor(app, AdminID.ordersEmpty)
        shot("S-A3-search-empty")
    }

    func testEmptyTodoListSaysAllDone() {
        let app = launch(AdminLaunch.modeEmpty)
        waitFor(app, AdminID.ordersEmpty)
        shot("S-A3-empty-todo")
        tap(app, AdminID.filterNew)
        waitFor(app, AdminID.ordersClearFilters)
        shot("S-A3-empty-filtered")
        tap(app, AdminID.ordersClearFilters)
        waitFor(app, AdminID.ordersEmpty)
    }

    func testOfflineAndServerErrorStatesOfferRetry() {
        let offline = launch(AdminLaunch.modeOffline)
        waitFor(offline, AdminID.ordersOffline)
        waitFor(offline, AdminID.ordersRetry)
        shot("S-A3-offline")
        offline.terminate()
        let error = launch(AdminLaunch.modeServerError)
        waitFor(error, AdminID.ordersError)
        shot("S-A3-error")
    }

    func testExpiredAccessTokenIsRefreshedWithoutBotheringThePerson() {
        let app = launch(AdminLaunch.modeRefresh)
        waitFor(app, AdminID.row("BT-7K3M9Q"))
        XCTAssertFalse(element(app, AdminID.signInEmail).exists)
    }

    func testOwnerSeesTabsAndSettingsPlaceholder() {
        let app = launch(AdminLaunch.modeOwner)
        waitFor(app, AdminID.row("BT-7K3M9Q"))
        _ = tab(app, index: 0)
        shot("S-A3-default-todo-owner")
        tab(app, index: 1).tap()
        waitFor(app, AdminID.settingsSignOut)
        shot("S-A6-settings-placeholder-owner")
    }
}
