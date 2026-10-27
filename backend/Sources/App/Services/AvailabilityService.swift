import Foundation
import BanhContracts

/// Builds the date list of `GET /v1/availability` (api.md 4.2) by applying
/// BR-2 (lead time), BR-8 (horizon) and BR-1 (daily capacity). It never takes
/// a slot: a slot does not change availability (BR-11).
struct AvailabilityService: Sendable {
    let repository: any AvailabilityRepository
    let calendar: ShopCalendar

    /// - Parameter requestedCakes: the raw `cakes` value; nil when it was
    ///   missing or not a whole number, which is the same client defect.
    /// - Throws: `APIError(.validationFailed)` for a missing or out-of-range `cakes`.
    func makeAvailability(shopID: UUID, requestedCakes: Int?) async throws -> AvailabilityResponse {
        let rules = try await repository.loadRules(shopID: shopID)
        let cakes = try Self.validate(requestedCakes, against: rules)

        // Today is read once, so every date of one answer shares one day.
        let today = calendar.today()
        let firstBookable = calendar.adding(days: rules.leadDays, to: today)
        let last = calendar.adding(days: rules.maxDaysAhead, to: today)
        let accepted = try await repository.loadAcceptedCakes(shopID: shopID, from: today, through: last)

        let dates = (0...rules.maxDaysAhead).map { offset -> AvailabilityDate in
            let date = calendar.adding(days: offset, to: today)
            let reason = Self.unavailabilityReason(
                of: date, cakes: cakes, firstBookable: firstBookable,
                accepted: accepted[date] ?? 0, dailyLimit: rules.dailyLimit
            )
            return AvailabilityDate(date: date.description, available: reason == nil, reason: reason)
        }
        return AvailabilityResponse(serverDate: today.description, dates: dates)
    }
}

extension AvailabilityService {
    static let cakesFieldName = "cakes"
    static let minCakes = 1
    static let cakesInvalidCode = "CAKES_INVALID"

    /// The lower bound `minCakes` is 1 (an order has at least one cake); the minimum
    /// order size of BR-4 is a separate rule checked when the order is placed.
    fileprivate static func validate(_ requested: Int?, against rules: AvailabilityRules) throws -> Int {
        guard let requested, requested >= minCakes, requested <= rules.maxCakesPerOrder else {
            throw APIError(.validationFailed, fields: [
                .init(field: cakesFieldName, code: cakesInvalidCode, messageKey: APIErrorCode.genericMessageKey)
            ])
        }
        return requested
    }

    /// Lead time wins over capacity: a date that is too soon is reported as
    /// such even when it is also full. `TOO_FAR` cannot occur because the list
    /// stops at the horizon.
    fileprivate static func unavailabilityReason(
        of date: BusinessDate, cakes: Int, firstBookable: BusinessDate, accepted: Int, dailyLimit: Int
    ) -> AvailabilityReason? {
        if date < firstBookable { return .tooSoon }
        // The current daily limit is used, not the one stored with the row
        // (data-model.md 3.6); an exact fit is still available.
        if dailyLimit - accepted < cakes { return .full }
        return nil
    }
}
