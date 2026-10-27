import Foundation

/// Body of `GET /v1/availability` (api.md 4.2): which dates can hold an order
/// of the requested number of cakes. Remaining amounts are never part of it.
public struct AvailabilityResponse: Codable, Equatable, Sendable {
    /// Today in shop time, `YYYY-MM-DD`.
    public let serverDate: String
    /// One entry per date from `serverDate` to `serverDate + max_days_ahead`, inclusive, in date order.
    public let dates: [AvailabilityDate]

    public init(serverDate: String, dates: [AvailabilityDate]) {
        self.serverDate = serverDate
        self.dates = dates
    }

    private enum CodingKeys: String, CodingKey {
        case serverDate = "server_date"
        case dates
    }
}

public struct AvailabilityDate: Codable, Equatable, Sendable {
    /// `YYYY-MM-DD` in shop time.
    public let date: String
    public let available: Bool
    /// Why the date cannot be chosen; nil exactly when `available` is true.
    public let reason: AvailabilityReason?

    public init(date: String, available: Bool, reason: AvailabilityReason?) {
        self.date = date
        self.available = available
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case available
        case reason
    }

    // The contract says `reason` is null when available, so the key is always
    // written; the synthesised encoder would drop it.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(available, forKey: .available)
        try container.encode(reason, forKey: .reason)
    }
}

/// Reasons of api.md 4.2. `tooFar` is part of the vocabulary but the list
/// never contains dates beyond the horizon, so the server does not emit it.
public enum AvailabilityReason: String, Codable, Equatable, Sendable {
    case tooSoon = "TOO_SOON"
    case tooFar = "TOO_FAR"
    case full = "FULL"
}
