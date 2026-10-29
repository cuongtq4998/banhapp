/// The configuration that decides which dates can hold an order
/// (data-model.md 3.2 and 3.3). Unlike `OrderingParameters` it carries the
/// daily limit, which is used for the capacity test and never sent to clients.
struct AvailabilityRules: Equatable, Sendable {
    /// BR-2: the earliest date is today plus this many days.
    let leadDays: Int
    /// BR-8: the latest date is today plus this many days.
    let maxDaysAhead: Int
    /// BR-1: cakes one date can hold.
    let dailyLimit: Int
    let activeProductCount: Int
    let maxQtyPerCake: Int

    /// Largest order the apps can build: every active cake at its maximum
    /// (api.md 4.2, `cakes` range).
    var maxCakesPerOrder: Int { maxQtyPerCake * activeProductCount }
}

/// The date rules written once: `AvailabilityService` lists dates with them
/// and `OrderPlacementService` re-checks the chosen date with the same code,
/// so the list and the order can never disagree.
extension AvailabilityRules {
    /// BR-2: the earliest date that can be ordered.
    func firstBookableDate(today: BusinessDate, calendar: ShopCalendar) -> BusinessDate {
        calendar.adding(days: leadDays, to: today)
    }

    /// BR-8: the latest date that can be ordered.
    func lastBookableDate(today: BusinessDate, calendar: ShopCalendar) -> BusinessDate {
        calendar.adding(days: maxDaysAhead, to: today)
    }

    /// BR-1: the current daily limit is used, not the one stored with the
    /// `day_load` row (data-model.md 3.6); an exact fit still has room.
    func hasRoom(forCakes cakes: Int, alreadyAccepted accepted: Int) -> Bool {
        dailyLimit - accepted >= cakes
    }
}
