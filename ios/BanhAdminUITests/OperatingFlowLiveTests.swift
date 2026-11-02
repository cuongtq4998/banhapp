import XCTest

/// The shop's operating flow on the real apps and a real local backend (steps 1 to 4 here, 5 and 6 in
/// `OperatingFlowLiveTests+Settings.swift`, 7 and 8 in `+Staff`). Methods run in name order and share
/// `LiveState`. Skipped unless `TEST_RUNNER_E2E_LIVE=1` (dev-guide, "Live end-to-end run").
final class OperatingFlowLiveTests: LiveCase {
    // Step 1: the customer app places two orders for the same phone.
    func test01_CustomerPlacesTwoOrders() throws {
        if Live.reuseOrders, state.order1 != nil, state.order2 != nil { throw XCTSkip("E2E_REUSE_ORDERS=1: orders of an earlier run are kept") }
        let catalog = LiveBackend.catalog()
        let products = catalog["products"] as? [[String: Any]] ?? []
        let districts = catalog["districts"] as? [[String: Any]] ?? []
        let slotID = (catalog["slots"] as? [[String: Any]])?.first?["slot_id"] as? String ?? ""
        let productID = products.first?["product_id"] as? String ?? ""
        let district = districts.first { $0["name"] as? String == "Quận 5" } ?? districts[0]
        let total = (products.first?["price_vnd"] as? Int ?? 0) * 2 + (district["delivery_fee_vnd"] as? Int ?? 0)
        let date = LiveBackend.firstAvailableDate()
        XCTAssertFalse(date.isEmpty, "no available date")
        let customer = LiveCustomer(test: self)
        let amount = Self.money(total)
        var first = LiveOrder(code: "", name: "Nguyen Van An", phone: Live.customerPhone, address: "12 Duong Test",
                              district: district["name"] as? String ?? "", date: date, total: amount)
        first.code = customer.place(first, productID: productID, slotID: slotID, districtID: district["district_id"] as? String ?? "") { self.evidence($0) }
        XCTAssertTrue(first.code.hasPrefix("BT-"), "order 1 has no code on S-9")
        var second = first
        second.name = "Spam Test"
        second.address = "34 Duong Spam"
        second.code = customer.place(second, productID: productID, slotID: slotID, districtID: district["district_id"] as? String ?? "") { self.evidence($0) }
        XCTAssertTrue(second.code.hasPrefix("BT-") && second.code != first.code, "order 2 has no own code on S-9")
        state.order1 = first
        state.order2 = second
    }

    // Steps 2 to 4: the owner signs in, confirms order 1, cancels order 2 as spam, completes order 1.
    func test02_OwnerConfirmsCancelsAndCompletes() throws {
        let (first, second) = try orders()
        let app = admin(fresh: true)
        signInLive(app, email: Live.ownerEmail)
        waitFor(app, AdminID.row(first.code))
        waitFor(app, AdminID.row(second.code))
        evidence("todo-list-two-new-orders", app: app)
        let badge = element(app, AdminID.ordersBadge)
        note("badge present: \(badge.waitForExistence(timeout: 3)) tab buttons: \(app.tabBars.buttons.allElementsBoundByIndex.map { $0.label + "/" + String(describing: $0.value) })")
        // Both are the only open orders, so both sit at the top; the list is ordered by delivery date, then oldest first.
        open(app, first.code)
        evidence("order1-detail-new", app: app)
        let productName = LiveBackend.productNames().first ?? ""
        let shown = [AdminID.detailPhone, AdminID.detailAddress, AdminID.detailCake(0), AdminID.detailTotal]
            .map { label(app, $0) }.joined(separator: " | ")
        note("detail of order 1: name shown=\(app.staticTexts[first.name].exists) | \(shown)")
        XCTAssertTrue(app.staticTexts[first.name].exists, "customer name \(first.name) is not on the detail")
        // The backend stores the phone as +84...; the customer typed 0900000101.
        for expected in ["+84" + first.phone.dropFirst(), first.address, first.district, productName, "2", first.total] {
            XCTAssertTrue(digitsFold(shown).contains(digitsFold(expected)), "detail lacks '\(expected)' in: \(shown)")
        }
        tap(app, AdminID.orderProcess)
        waitFor(app, AdminID.detailStatus)
        XCTAssertTrue(waitForLabel(app, AdminID.detailStatus, contains: "Đã xác nhận"), label(app, AdminID.detailStatus))
        evidence("order1-confirmed", app: app)
        backToList(app)

        open(app, second.code)
        tap(app, AdminID.detailCancel)
        tap(app, AdminID.cancelSpam)
        evidence("order2-cancel-reason", app: app)
        tap(app, AdminID.cancelConfirm)
        waitFor(app, AdminID.detailReason)
        XCTAssertTrue(label(app, AdminID.detailReason).contains("Đơn giả hoặc spam"), label(app, AdminID.detailReason))
        evidence("order2-cancelled-spam", app: app)
        backToList(app)

        open(app, first.code)
        tap(app, AdminID.orderFinish)
        tap(app, AdminID.detailCompleteYes)
        XCTAssertTrue(waitForLabel(app, AdminID.detailStatus, contains: "Đã hoàn thành"), label(app, AdminID.detailStatus))
        evidence("order1-completed", app: app)
        backToList(app)
        tapChip(app, AdminID.filterFinished)
        waitFor(app, AdminID.row(first.code))
        evidence("completed-list", app: app)
        tapChip(app, AdminID.filterTodo)
    }

    /// Step 3, API half: orders 1 and 2 count for the phone; three more make five; the sixth is refused with
    /// 429 `RATE_LIMITED` (api/03 step 7). Had the spam order stopped counting, the sixth would be stored.
    func test02b_PhoneLimitStillCountsTheSpamOrder() throws {
        _ = try orders()
        let date = LiveBackend.firstAvailableDate(skip: 5)
        for number in 3...5 {
            let reply = LiveBackend.placeOrder(phone: Live.customerPhone, date: date, name: "Limit Probe \(number)")
            XCTAssertEqual(reply.status, 201, "order \(number) for the phone: \(reply.text)")
        }
        let sixth = LiveBackend.placeOrder(phone: Live.customerPhone, date: date, name: "Limit Probe 6")
        note("6th order for the phone: HTTP \(sixth.status) \(sixth.text)")
        XCTAssertEqual(sixth.status, 429, sixth.text)
        XCTAssertEqual((sixth.json["error"] as? [String: Any])?["code"] as? String, "RATE_LIMITED", sixth.text)
    }
}
