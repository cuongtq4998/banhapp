#if DEBUG
import BanhContracts
import Foundation

/// `GET /v1/availability` for the UI tests, in the shape of `availability-ok.json`: server date
/// 2026-11-02, lead time 2 days, horizon 30 days, daily limit 100. 2026-11-05 holds 98 cakes and
/// 2026-11-20 holds 100, so an order of 3 cakes does not fit those days and an order of 2 fits the first.
nonisolated struct StubAvailabilityAPI: AvailabilityAPI {
    /// Nil answers like the real API; a failure is returned for every call.
    let result: Result<AvailabilityResponse, APIError>?

    private static let serverDate = ShopDate(year: 2026, month: 11, day: 2)
    private static let leadDays = 2
    private static let horizonDays = 30
    private static let dailyLimit = 100
    private static let cakesAlreadyBooked: [String: Int] = ["2026-11-05": 98, "2026-11-20": 100]

    func fetchAvailability(cakes: Int) async throws -> AvailabilityResponse {
        if let result { return try result.get() }
        let dates = (0...Self.horizonDays).map { offset -> AvailabilityDate in
            let date = Self.serverDate.adding(days: offset)
            let remaining = Self.dailyLimit - (Self.cakesAlreadyBooked[date.iso] ?? 0)
            if offset < Self.leadDays { return AvailabilityDate(date: date.iso, available: false, reason: .tooSoon) }
            if remaining < cakes { return AvailabilityDate(date: date.iso, available: false, reason: .full) }
            return AvailabilityDate(date: date.iso, available: true, reason: nil)
        }
        return AvailabilityResponse(serverDate: Self.serverDate.iso, dates: dates)
    }
}
#endif
