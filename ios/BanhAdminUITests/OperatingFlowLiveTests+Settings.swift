import XCTest

/// Steps 5 and 6: ordering limit and impact preview, then a new cake (uploaded by a helper) and hiding it.
extension OperatingFlowLiveTests {
    private var cakeName: String { "Banh Thu E2E" }

    func test03_OwnerLowersAndRestoresTheDailyLimit() throws {
        let (first, _) = try orders()
        let app = admin()
        openSettingsTab(app, row: AdminOwnerID.rowRules)
        // A failed earlier run may have left the limit at 1: put the sample values back first.
        if label(app, AdminOwnerID.rulesLimit).filter(\.isNumber) != "30" {
            replaceText(app, AdminOwnerID.rulesLimit, with: "30")
            replaceText(app, AdminOwnerID.rulesMin, with: "2")
            dismissKeyboard(app)
            tap(app, AdminOwnerID.rulesSave)
            if element(app, AdminOwnerID.rulesWarnConfirm).waitForExistence(timeout: 2) { tap(app, AdminOwnerID.rulesWarnConfirm) }
            waitFor(app, AdminOwnerID.rowCakes)
            openSettingsTab(app, row: AdminOwnerID.rowRules)
        }
        let before = "30" // the sample shop's values (a failed earlier run may have left 1)
        evidence("rules-before", app: app)
        let minBefore = "2"
        // The minimum order (2) may not exceed the limit, so both go down to 1: the 2 cakes of order 1 are then over it.
        replaceText(app, AdminOwnerID.rulesMin, with: "1")
        replaceText(app, AdminOwnerID.rulesLimit, with: "1")
        dismissKeyboard(app)
        tap(app, AdminOwnerID.rulesSave)
        waitFor(app, AdminOwnerID.rulesWarnConfirm)
        let day = String(first.date.suffix(2)) + "/" + String(first.date.dropFirst(5).prefix(2))
        let dialog = app.descendants(matching: .any).matching(identifier: AdminOwnerID.rulesWarnDialog).firstMatch
        let text = (app.alerts.firstMatch.exists ? app.alerts.firstMatch.label : "") + " " + dialog.label + " " + app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        note("impact preview text: \(text)")
        XCTAssertTrue(text.contains(day), "the preview does not list \(day): \(text)")
        evidence("rules-impact-preview", app: app)
        tap(app, AdminOwnerID.rulesWarnConfirm)
        waitFor(app, AdminOwnerID.rowCakes)

        let customer = LiveCustomer(test: self)
        customer.launch()
        let productID = (LiveBackend.catalog()["products"] as? [[String: Any]])?.first?["product_id"] as? String ?? ""
        customer.openDateStep(productID: productID)
        let cell = customer.wait(LiveCustomer.ID.date(first.date))
        note("customer date \(first.date) with limit 1: enabled=\(cell.isEnabled) label=\(cell.label)")
        XCTAssertFalse(cell.isEnabled, "the full date can still be chosen: \(cell.label)")
        evidence("customer-date-full")
        let api = LiveBackend.send("GET", "/v1/availability?cakes=2").json["dates"] as? [[String: Any]] ?? []
        let reason = api.first { $0["date"] as? String == first.date }?["reason"] as? String
        note("API reason for \(first.date): \(reason ?? "nil")")
        XCTAssertEqual(reason, "FULL", "API reason")

        let again = admin()
        openSettingsTab(again, row: AdminOwnerID.rowRules)
        replaceText(again, AdminOwnerID.rulesLimit, with: before.filter(\.isNumber).isEmpty ? "30" : before.filter(\.isNumber))
        replaceText(again, AdminOwnerID.rulesMin, with: minBefore.isEmpty ? "2" : minBefore)
        dismissKeyboard(again)
        tap(again, AdminOwnerID.rulesSave)
        if element(again, AdminOwnerID.rulesWarnConfirm).waitForExistence(timeout: 2) { tap(again, AdminOwnerID.rulesWarnConfirm) }
        waitFor(again, AdminOwnerID.rowCakes)
        evidence("rules-restored", app: again)
        let after = LiveBackend.send("GET", "/v1/availability?cakes=2").json["dates"] as? [[String: Any]] ?? []
        XCTAssertEqual(after.first { $0["date"] as? String == first.date }?["available"] as? Bool, true, "limit restored")
    }

    func test04_OwnerAddsAndHidesACake() throws {
        let app = admin()
        openSettingsTab(app, row: AdminOwnerID.rowCakes)
        tap(app, AdminOwnerID.cakesAdd)
        waitFor(app, AdminOwnerID.cakeName)
        replaceText(app, AdminOwnerID.cakeName, with: cakeName)
        replaceText(app, AdminOwnerID.cakeDesc, with: "Banh thu nghiem cho kiem tra.")
        replaceText(app, AdminOwnerID.cakePrice, with: "50000")
        dismissKeyboard(app)
        evidence("cake-form-filled-no-photo", app: app)
        tap(app, AdminOwnerID.cakeSave)
        waitFor(app, AdminOwnerID.fieldError("cakeForm", "image"))
        evidence("cake-form-photo-required", app: app)
        tap(app, AdminOwnerID.back("cakeForm"))
        if element(app, AdminOwnerID.discardConfirm).waitForExistence(timeout: 3) { tap(app, AdminOwnerID.discardConfirm) }
        waitFor(app, AdminOwnerID.cakesAdd)

        // PhotosPicker cannot be driven: the same request the app sends (multipart) comes from a helper.
        guard let token = LiveOwnerAPI.signIn(Live.ownerEmail) else { return XCTFail("owner API sign-in failed") }
        Self.ownerToken = token
        let reply = LiveOwnerAPI.addCake(token: token, name: cakeName, description: "Banh thu nghiem cho kiem tra.", price: 50000)
        XCTAssertEqual(reply.status, 201, reply.text)
        let id = reply.json["cake_id"] as? String ?? ""
        state.cakeID = id
        state.cakeName = cakeName
        note("cake uploaded by helper POST /v1/owner/cakes: \(reply.status) \(id)")

        tap(app, AdminOwnerID.back("cakes"))
        waitFor(app, AdminOwnerID.rowCakes)
        tap(app, AdminOwnerID.rowCakes)
        waitFor(app, AdminOwnerID.cakeRow(id))
        evidence("cakes-list-with-new-cake", app: app)

        try assertCustomerShows(cakeName, visible: true, shot: "customer-catalog-with-new-cake")

        let owner = admin()
        tap(owner, AdminOwnerID.cakeRow(id))
        waitFor(owner, AdminOwnerID.cakeActive)
        flip(owner, AdminOwnerID.cakeActive)
        evidence("cake-edit-hidden", app: owner)
        tap(owner, AdminOwnerID.cakeSave)
        waitFor(owner, AdminOwnerID.cakesAdd)
        try assertCustomerShows(cakeName, visible: false, shot: "customer-catalog-cake-hidden")
    }

    private func assertCustomerShows(_ name: String, visible: Bool, shot: String) throws {
        let customer = LiveCustomer(test: self)
        customer.launch()
        customer.tap(LiveCustomer.ID.products)
        customer.wait(LiveCustomer.ID.productsList)
        let match = customer.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        if visible {
            XCTAssertTrue(match.waitForExistence(timeout: 10), "\(name) is not in the customer catalog")
        } else {
            Thread.sleep(forTimeInterval: 2)
            XCTAssertFalse(match.exists, "\(name) is still in the customer catalog")
        }
        evidence(shot)
    }
}
