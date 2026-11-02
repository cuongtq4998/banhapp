import BanhCore
import Foundation
import Observation

/// S-A3: the order list with its filters, search, paging and the number for the tab badge.
@Observable
final class OrderListViewModel {
    private(set) var rows: [OrderSummary] = []
    private(set) var state: Load<Void> = .loading
    private(set) var unfinishedCount = 0
    /// Shop date of the first page of this load; the due marks use it, never the device clock (TQ-D8).
    private(set) var serverDate = ""
    private(set) var isLoadingMore = false
    private(set) var loadMoreFailed = false
    private(set) var isRefreshing = false

    private(set) var status: OrderQuery.StatusFilter = .todo
    private(set) var date: OrderQuery.DateFilter = .any
    var searchText = "" {
        didSet {
            // The API takes 50 characters at most; a longer paste is cut (spec 5, search).
            if searchText.count > Self.maxSearchLength { searchText = String(searchText.prefix(Self.maxSearchLength)) }
            if searchText != oldValue { searchChanged() }
        }
    }
    static let maxSearchLength = 50

    private let api: any OrdersAPI
    private let debounce: Duration
    private var nextCursor: String?
    private var loadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var generation = 0
    private var lastLoad = Date.distantPast
    private let now: () -> Date

    /// Rows loaded per page and how near the end the next page is requested (BR-9).
    static let loadMoreThreshold = 5
    static let staleAfter: TimeInterval = 60

    init(api: any OrdersAPI, debounce: Duration = .milliseconds(400), now: @escaping () -> Date = Date.init) {
        self.api = api
        self.debounce = debounce
        self.now = now
    }

    // MARK: Derived

    var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var searchIsActive: Bool { trimmedSearch.count >= OrderQuery.minSearchLength }
    /// 1 or 2 typed characters: the search waits and the hint says why (BR-10).
    var showsSearchMin: Bool { !trimmedSearch.isEmpty && !searchIsActive }
    var hasNarrowingFilter: Bool { status != .todo || date != .any }

    enum EmptyKind { case search, filtered, todo }
    var emptyKind: EmptyKind {
        if searchIsActive { return .search }
        return hasNarrowingFilter ? .filtered : .todo
    }

    func due(for row: OrderSummary) -> DueState? {
        DueState.of(status: row.status, deliveryDate: row.deliveryDate, serverDate: serverDate)
    }

    private var query: OrderQuery {
        OrderQuery(status: status, date: date, search: searchIsActive ? String(trimmedSearch.prefix(100)) : "")
    }

    // MARK: Loading

    /// Reloads from the first page. Old rows stay while a refresh runs; a failure with rows shown
    /// replaces them (an old list is never presented as current, AC-20).
    func reload() async {
        loadTask?.cancel()
        generation += 1
        let mine = generation
        isRefreshing = true
        if rows.isEmpty { state = .loading }
        var pageQuery = query
        pageQuery.cursor = nil
        do {
            let page = try await api.orders(pageQuery)
            guard mine == generation else { return }
            rows = page.items
            nextCursor = page.nextCursor
            unfinishedCount = page.unfinishedCount
            serverDate = page.serverDate
            loadMoreFailed = false
            state = .ready(())
            lastLoad = now()
        } catch {
            guard mine == generation, !Task.isCancelled, !(error is SessionEnded) else { return }
            rows = []
            nextCursor = nil
            state = .failed((error as? APIError)?.isConnectivity == true ? .network : .other)
        }
        if mine == generation { isRefreshing = false }
    }

    /// Opening, returning to the app after more than 60 s, and the pull-down all end here.
    func reloadIfStale() async {
        guard state.isLoading || now().timeIntervalSince(lastLoad) > Self.staleAfter else { return }
        await reload()
    }

    func rowAppeared(_ row: OrderSummary) {
        guard let index = rows.firstIndex(of: row), index >= rows.count - Self.loadMoreThreshold else { return }
        Task { await loadMore() }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, case .ready = state else { return }
        isLoadingMore = true
        loadMoreFailed = false
        let mine = generation
        var pageQuery = query
        pageQuery.cursor = cursor
        do {
            let page = try await api.orders(pageQuery)
            guard mine == generation else { return }
            let known = Set(rows.map(\.id))
            rows += page.items.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
            unfinishedCount = page.unfinishedCount
        } catch {
            if mine == generation, !(error is SessionEnded) { loadMoreFailed = true }
        }
        isLoadingMore = false
    }

    // MARK: Filters and search

    func select(status newStatus: OrderQuery.StatusFilter) {
        guard newStatus != status else { return }
        status = newStatus
        restart()
    }

    func select(date newDate: OrderQuery.DateFilter) {
        guard newDate != date else { return }
        date = newDate
        restart()
    }

    func clearFilters() {
        status = .todo
        date = .any
        searchText = ""
        restart()
    }

    /// The search key: search now, without waiting for the pause.
    func submitSearch() {
        searchTask?.cancel()
        if searchIsActive { restart() }
    }

    private func searchChanged() {
        searchTask?.cancel()
        let wasSearching = lastSearchApplied
        guard searchIsActive || wasSearching else { return }
        searchTask = Task { [weak self, debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self?.restart()
        }
    }

    /// Whether the rows on screen came from a search (so clearing the field must reload).
    private var lastSearchApplied = false

    private func restart() {
        lastSearchApplied = searchIsActive
        loadTask?.cancel()
        loadTask = Task { await reload() }
    }
}
