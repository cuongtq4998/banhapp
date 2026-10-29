import BanhContracts

/// What the calendar shows for one day (UI document 5.6): the server's answer for dates in its list,
/// and the two ends of the range for dates outside it.
enum DayState: Equatable {
    case available
    case selected
    /// Enough room is missing for the order (diagonal strike).
    case full
    /// Before today + LEAD_DAYS, or already past (dimmed).
    case tooSoon
    /// After today + MAX_DAYS_AHEAD (dimmed).
    case tooFar

    var isSelectable: Bool { self == .available || self == .selected }
}

/// The answer of `GET /v1/availability`, keyed by date for the calendar.
struct DayAvailability: Equatable {
    let serverDate: ShopDate
    let lastDate: ShopDate
    private let entries: [ShopDate: Entry]

    private enum Entry: Equatable {
        case open
        case closed(AvailabilityReason)
    }

    init?(response: AvailabilityResponse) {
        guard let serverDate = ShopDate(iso: response.serverDate) else { return nil }
        var entries: [ShopDate: Entry] = [:]
        for entry in response.dates {
            guard let date = ShopDate(iso: entry.date) else { return nil }
            entries[date] = entry.available ? .open : .closed(entry.reason ?? .full)
        }
        guard let last = entries.keys.max() else { return nil }
        self.serverDate = serverDate
        self.lastDate = last
        self.entries = entries
    }

    var hasSelectableDate: Bool { entries.values.contains(.open) }

    var firstSelectableDate: ShopDate? {
        entries.filter { $0.value == .open }.keys.min()
    }

    func state(of date: ShopDate) -> DayState {
        if date < serverDate { return .tooSoon }
        if date > lastDate { return .tooFar }
        switch entries[date] ?? .closed(.tooSoon) {
        case .open: return .available
        case .closed(.tooSoon): return .tooSoon
        case .closed(.tooFar): return .tooFar
        case .closed(.full): return .full
        }
    }
}
