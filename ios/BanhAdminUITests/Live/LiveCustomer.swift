import XCTest

/// Drives the customer app (bundle `app.banh.customer`, real backend, no stub) from the admin UI test target.
/// Identifiers are the literal values of `ios/Shared/AccessibilityID.swift` (that file is not compiled into
/// this target, and the project file is left alone).
struct LiveCustomer {
    let test: LiveCase
    let app = XCUIApplication(bundleIdentifier: Live.customerBundle)

    enum ID {
        static let order = "home.orderButton", products = "home.productsButton", step = "order.step", next = "order.next"
        static let name = "order.field.name", phone = "order.field.phone", address = "order.field.address"
        static let district = "order.field.district", nextMonth = "order.date.next"
        static let total = "review.total", confirm = "review.confirm", code = "confirmation.code", home = "confirmation.homeButton"
        static let productsList = "products.list", back = "nav.back"
        static func inc(_ id: String) -> String { "order.qty.\(id).inc" }
        static func date(_ iso: String) -> String { "order.date.\(iso)" }
        static func slot(_ id: String) -> String { "order.slot.\(id)" }
        static func districtRow(_ id: String) -> String { "order.district.row.\(id)" }
    }

    func launch() { app.launch() }

    func el(_ id: String) -> XCUIElement { test.element(app, id) }
    @discardableResult func wait(_ id: String) -> XCUIElement { test.waitFor(app, id) }
    func tap(_ id: String) { test.tap(app, id) }

    func reveal(_ id: String) {
        let target = wait(id)
        var tries = 0
        while !target.isHittable && tries < 4 { app.swipeUp(); tries += 1 }
    }

    /// Opens the date step with `cakes` cakes of the first product and returns on S-6.
    func openDateStep(productID: String, cakes: Int = 2) {
        tap(ID.order)
        wait(ID.step)
        for _ in 0..<cakes { tap(ID.inc(productID)) }
        tap(ID.next)
    }

    /// Chooses the date (turning the month when needed) and slot, then Next.
    func chooseDate(_ iso: String, slotID: String) {
        var turns = 0
        while !el(ID.date(iso)).waitForExistence(timeout: 2), turns < 2 { tap(ID.nextMonth); turns += 1 }
        tap(ID.date(iso))
        tap(ID.slot(slotID))
        tap(ID.next)
    }

    func fill(_ order: LiveOrder, districtID: String) {
        wait(ID.name).tap()
        app.typeText(order.name)
        el(ID.phone).tap()
        app.typeText(order.phone)
        reveal(ID.address)
        el(ID.address).tap()
        app.typeText(order.address)
        reveal(ID.district)
        tap(ID.district)
        tap(ID.districtRow(districtID))
        tap(ID.next)
    }

    /// The whole customer flow for one order: 2 cakes, the date, the recipient, confirm. Returns the code.
    func place(_ order: LiveOrder, productID: String, slotID: String, districtID: String, shot: (String) -> Void) -> String {
        launch()
        openDateStep(productID: productID)
        shot("customer-date-step")
        chooseDate(order.date, slotID: slotID)
        fill(order, districtID: districtID)
        wait(ID.total)
        shot("customer-review")
        tap(ID.confirm)
        let shown = wait(ID.code).label
        shot("customer-confirmation")
        let code = shown.range(of: "BT-[A-Z0-9]{6}", options: .regularExpression).map { String(shown[$0]) } ?? ""
        tap(ID.home)
        return code
    }
}
