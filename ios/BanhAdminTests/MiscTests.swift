import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

struct MiscTests {
    @Test func dueStateOnlyForOpenOrdersOnOrBeforeTheServerDate() {
        #expect(DueState.of(status: .received, deliveryDate: "2026-11-02", serverDate: "2026-11-02") == .today)
        #expect(DueState.of(status: .processing, deliveryDate: "2026-10-31", serverDate: "2026-11-02") == .overdue(days: 2))
        #expect(DueState.of(status: .received, deliveryDate: "2026-11-03", serverDate: "2026-11-02") == nil)
        #expect(DueState.of(status: .finished, deliveryDate: "2026-10-01", serverDate: "2026-11-02") == nil)
        #expect(DueState.of(status: .cancelled, deliveryDate: "2026-10-01", serverDate: "2026-11-02") == nil)
    }

    @Test func versionHeaderIsFilledToThreeGroups() {
        #expect(BuildConfiguration.headerVersion("1.0") == "1.0.0")
        #expect(BuildConfiguration.headerVersion("1.2.3") == "1.2.3")
        #expect(BuildConfiguration.headerVersion("1.0-beta") == "0.0.0")
    }

    @Test func dateTimeShowsVietnamTime() {
        #expect(AdminFormatting.dateTime("2026-10-31T03:15:09Z") == "31/10/2026 10:15")
    }

    @Test func contactLinks() {
        #expect(ContactLinks.phoneURL("+84900000010")?.absoluteString == "tel:+84900000010")
        #expect(ContactLinks.zaloURL("+84900000010")?.absoluteString == "https://zalo.me/84900000010")
        #expect(ContactLinks.zaloURL("") == nil)
    }

    @Test func queryItemsFollowTheContract() {
        let query = OrderQuery(status: .received, date: .day("2026-11-04"), search: "abc", cursor: "c")
        let names = query.items.map(\.name)
        #expect(names == ["status", "delivery_date", "q", "cursor"])
    }

    @Test func tokenStoreSeparatesPendingSignOut() {
        let store = InMemoryTokenStore(refreshToken: "a")
        store.savePendingSignOut("b")
        store.clearRefreshToken()
        #expect(store.refreshToken == nil && store.pendingSignOutToken == "b")
        store.clearAll()
        #expect(store.pendingSignOutToken == nil)
    }
}
