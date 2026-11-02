import XCTest

extension LiveCase {
    static func money(_ vnd: Int) -> String {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = "."
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: vnd)) ?? "\(vnd)") + " ₫"
    }

    func orders() throws -> (LiveOrder, LiveOrder) {
        guard let first = state.order1, let second = state.order2 else {
            throw XCTSkip("step 1 did not store the two orders")
        }
        return (first, second)
    }

    /// Lower case without diacritics and without spaces or dots, so "090 000 0101" equals "0900000101".
    func digitsFold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .filter { !$0.isWhitespace && $0 != "." && $0 != "-" }
    }

    func waitForLabel(_ app: XCUIApplication, _ identifier: String, contains text: String, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element(app, identifier).exists, label(app, identifier).contains(text) { return true }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return false
    }
}
