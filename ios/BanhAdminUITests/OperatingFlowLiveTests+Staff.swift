import XCTest

/// Steps 7 and 8: staff account lifecycle and the privacy audit of the backend log.
extension OperatingFlowLiveTests {
    func test05a_OwnerAddsStaff() throws {
        let app = admin()
        if element(app, AdminID.signInEmail).waitForExistence(timeout: 4) { signInLive(app, email: Live.ownerEmail) } // a run of this method alone
        openSettingsTab(app, row: AdminOwnerID.rowStaff)
        for (name, email) in [(Live.staffName, Live.staffEmail), ("Staff Two", "staff.ios2@example.com")] {
            tap(app, AdminOwnerID.staffAdd)
            replaceText(app, AdminOwnerID.staffAddName, with: name)
            replaceText(app, AdminOwnerID.staffAddEmail, with: email)
            dismissKeyboard(app)
            tap(app, AdminOwnerID.staffAddSave)
            waitFor(app, AdminID.toast)
            evidence("staff-added-\(email.prefix(10))", app: app)
        }
        // The second member is deactivated in the UI (the first one must keep a session on the phone).
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "staff.ios2@example.com")).firstMatch
        if row.waitForExistence(timeout: 5) {
            row.tap()
            tap(app, AdminOwnerID.staffDeactivate)
            tap(app, AdminOwnerID.staffDeactivateYes)
            waitFor(app, AdminID.toast)
            evidence("staff2-deactivated-in-ui", app: app)
        } else {
            XCTFail("row of staff.ios2@example.com not found")
        }
        goBack(app)
        waitFor(app, AdminOwnerID.rowStaff)
    }

    /// The owner (signed in again, or still signed in) signs out; the staff member signs in, works, and is
    /// deactivated by the owner while the session is on the phone (the owner side is an API call, because one
    /// phone holds one session).
    func test05b_StaffSignsInAndIsDeactivated() throws {
        let (first, _) = try orders()
        let app = admin()
        if element(app, AdminID.signInEmail).waitForExistence(timeout: 4) { signInLive(app, email: Live.ownerEmail) }
        openSettingsTab(app, row: AdminOwnerID.rowStaff)
        evidence("staff-list-both-added", app: app)
        goBack(app)
        tap(app, AdminOwnerID.rowCakes)
        waitFor(app, AdminOwnerID.cakesAdd)
        evidence("cakes-list-thumbnail-clipped", app: app) // the 3:2 photo must stay inside its square
        goBack(app)
        signOutOwner(app)

        signInLive(app, email: Live.staffEmail)
        XCTAssertEqual(app.tabBars.count, 0, "staff must not see a tab bar")
        waitFor(app, AdminID.row(first.code))
        evidence("staff-order-list-no-tab-bar", app: app)
        open(app, first.code)
        evidence("staff-order-detail", app: app)
        backToList(app)

        // The owner's helper session (the phone cannot hold two): a second sign-in by code.
        Self.ownerToken = Self.ownerToken ?? LiveOwnerAPI.signIn(Live.ownerEmail)
        guard let token = Self.ownerToken else { return XCTFail("no owner token") }
        let off = LiveOwnerAPI.setStaffActive(token: token, email: Live.staffEmail, active: false)
        XCTAssertEqual(off.status, 200, "deactivate: \(off.text)")
        note("owner deactivated \(Live.staffEmail) through PATCH /v1/owner/staff/{id}: \(off.status)")
        showCakeInCustomerCatalog(token: token)
        admin().activate()
        tapChip(app, AdminID.filterConfirmed)
        waitFor(app, AdminID.signInEmail)
        waitFor(app, AdminID.signInBanner)
        note("session-ended banner: \(label(app, AdminID.signInBanner))")
        evidence("staff-session-ended", app: app)
    }

    func test06_SignOutAndBackendLogHasNoPersonalData() throws {
        if let token = Self.ownerToken { LiveOwnerAPI.signOut(token: token) }
        let (first, second) = try orders()
        let secrets = [first.name, second.name, first.phone, first.phone.dropFirst().description, first.address, second.address,
                       Live.ownerEmail, Live.staffEmail, "staff.ios2@example.com"]
        let leaks = LiveLog.leaks(values: secrets, codes: LiveLog.seenCodes)
        note("log audit: \(leaks.count) leaking lines")
        XCTAssertTrue(leaks.isEmpty, "personal data in the log: \(leaks.prefix(5))")
        evidence("final-state", app: admin())
    }

    private func signOutOwner(_ app: XCUIApplication) {
        waitFor(app, AdminID.settingsSignOut)
        tap(app, AdminID.settingsSignOut)
        tap(app, AdminID.settingsSignOutYes)
        waitFor(app, AdminID.signInEmail)
        evidence("owner-signed-out", app: app)
    }

    /// Shows the uploaded cake once more (the thumbnail fix is checked on the customer card) and hides it again.
    private func showCakeInCustomerCatalog(token: String) {
        guard let id = state.cakeID else { return }
        _ = LiveBackend.send("PATCH", "/v1/owner/cakes/\(id)", token: token, json: ["is_active": true])
        let customer = LiveCustomer(test: self)
        customer.launch()
        customer.tap(LiveCustomer.ID.products)
        customer.wait(LiveCustomer.ID.productsList)
        Thread.sleep(forTimeInterval: 2)
        customer.app.swipeUp()
        evidence("customer-catalog-thumbnail-clipped")
        _ = LiveBackend.send("PATCH", "/v1/owner/cakes/\(id)", token: token, json: ["is_active": false])
    }
}
