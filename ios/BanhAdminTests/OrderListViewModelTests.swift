import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

@MainActor
struct OrderListViewModelTests {
    private func model(_ api: FakeOrdersAPI) -> OrderListViewModel {
        OrderListViewModel(api: api, debounce: .milliseconds(1))
    }

    @Test func firstLoadDefaultsToTodoAndKeepsTheServerCount() async {
        let api = FakeOrdersAPI()
        api.pages = [TestData.page(["BT-7K3M9Q"], unfinished: 3)]
        let model = model(api)
        await model.reload()
        #expect(api.queries.first?.items.contains(URLQueryItem(name: "status", value: "todo")) == true)
        #expect(model.rows.count == 1)
        #expect(model.unfinishedCount == 3)
        #expect(model.serverDate == "2026-11-02")
    }

    @Test func searchNeedsThreeCharactersAndSubmitSearchesAtOnce() async {
        let api = FakeOrdersAPI()
        api.pages = [TestData.page(["BT-7K3M9Q"])]
        let model = model(api)
        await model.reload()
        model.searchText = "tr"
        #expect(model.showsSearchMin)
        #expect(!model.searchIsActive)
        model.submitSearch()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(api.queries.count == 1)
        model.searchText = "tra"
        model.submitSearch()
        try? await Task.sleep(for: .milliseconds(100))
        #expect(!model.showsSearchMin)
        #expect(api.queries.last?.items.contains(URLQueryItem(name: "q", value: "tra")) == true)
    }

    @Test func spacesAroundTheSearchAreTrimmedBeforeCounting() async {
        let model = model(FakeOrdersAPI())
        model.searchText = "  ab  "
        #expect(model.showsSearchMin)
        #expect(OrderQuery(search: "ab").items.contains { $0.name == "q" } == false)
    }

    @Test func choosingAStatusOrDateReloadsFromTheFirstPage() async {
        let api = FakeOrdersAPI()
        api.pages = [TestData.page(["BT-7K3M9Q"])]
        let model = model(api)
        await model.reload()
        model.select(status: .confirmed)
        model.select(date: .tomorrow)
        try? await Task.sleep(for: .milliseconds(100))
        let items = api.queries.last?.items ?? []
        #expect(items.contains(URLQueryItem(name: "status", value: "Confirmed")))
        #expect(items.contains(URLQueryItem(name: "date_preset", value: "tomorrow")))
        #expect(!items.contains { $0.name == "cursor" })
    }

    @Test func nextPageLoadsNearTheEndAndFailureKeepsEarlierRows() async {
        let api = FakeOrdersAPI()
        api.pages = [TestData.page(["BT-7K3M9Q", "BT-4H8N2P"], next: "c1"), TestData.page(["BT-9D6R3T"])]
        let model = model(api)
        await model.reload()
        await model.loadMore()
        #expect(model.rows.map(\.orderCode) == ["BT-7K3M9Q", "BT-4H8N2P", "BT-9D6R3T"])
        #expect(api.queries.last?.cursor == "c1")

        let failing = FakeOrdersAPI()
        failing.pages = [TestData.page(["BT-7K3M9Q"], next: "c1")]
        let second = self.model(failing)
        await second.reload()
        failing.pages = []
        await second.loadMore()
        #expect(second.loadMoreFailed)
        #expect(second.rows.count == 1)
    }

    @Test func dueMarkUsesTheServerDate() async {
        let api = FakeOrdersAPI()
        api.pages = [OrderPage(items: [
            TestData.summary("BT-7K3M9Q", date: "2026-11-02"), TestData.summary("BT-4H8N2P", status: .confirmed, date: "2026-10-31"),
            TestData.summary("BT-9D6R3T", date: "2026-11-03"), TestData.summary("BT-6F3J8M", status: .completed, date: "2026-10-30"),
        ], nextCursor: nil, unfinishedCount: 2, serverDate: "2026-11-02")]
        let model = model(api)
        await model.reload()
        #expect(model.due(for: model.rows[0]) == .today)
        #expect(model.due(for: model.rows[1]) == .overdue(days: 2))
        #expect(model.due(for: model.rows[2]) == nil)
        #expect(model.due(for: model.rows[3]) == nil)
    }

    @Test func failuresPickTheirState() async {
        let model = model(FakeOrdersAPI())
        await model.reload()
        guard case .failed(.network) = model.state else { Issue.record("expected network failure"); return }
        #expect(model.rows.isEmpty)
    }

    @Test func emptyKindFollowsFiltersAndSearch() async {
        let api = FakeOrdersAPI()
        api.pages = [TestData.page([])]
        let model = model(api)
        await model.reload()
        #expect(model.emptyKind == .todo)
        model.select(status: .new)
        #expect(model.emptyKind == .filtered)
        model.searchText = "abc"
        #expect(model.emptyKind == .search)
    }

    @Test func searchTextIsCutAtFiftyCharacters() {
        let model = model(FakeOrdersAPI())
        model.searchText = String(repeating: "a", count: 80)
        #expect(model.searchText.count == 50)
    }
}
