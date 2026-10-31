import BanhContracts
import Foundation

/// What the banner at the top of S-8 says after a failed send (UI document 5.8, Error states a to c).
/// The cases carry only the numbers their text needs; the text is the app's own, never the server's.
enum SendNotice: Equatable {
    /// (a) A rule is not met: confirm stays blocked until the order changes.
    case minQty(Int)
    case dateCapacity(deliveryDate: String)
    case dateLead(days: Int)
    case dateHorizon(maxDays: Int)
    case districtUnserved
    case productUnavailable
    case slotUnavailable
    /// (b) Not sent, nothing the customer must change: retry sends the same attempt again.
    case offline
    case timeout
    case server
    case rateLimited(retryAfterSeconds: Int)
    /// (c) Nothing was sent; the review shows the new prices and confirm stays enabled.
    case priceChanged

    enum Kind { case rule, notSent, priceChanged }

    var kind: Kind {
        switch self {
        case .offline, .timeout, .server, .rateLimited: .notSent
        case .priceChanged: .priceChanged
        default: .rule
        }
    }

    /// The step that fixes a rule error; nil for the other kinds.
    var fixStep: OrderStep? {
        switch self {
        case .minQty, .productUnavailable: .cakes
        case .dateCapacity, .dateLead, .dateHorizon, .slotUnavailable: .date
        case .districtUnserved: .recipient
        default: nil
        }
    }

    var actionTitle: LocalizedStringResource? {
        switch self {
        case .minQty, .productUnavailable: OrderStrings.dateEmptyAction
        case .dateCapacity, .dateLead, .dateHorizon: OrderStrings.actionChooseDate
        case .slotUnavailable: OrderStrings.actionChooseSlot
        case .districtUnserved: OrderStrings.actionChooseDistrict
        case .offline, .timeout, .server, .rateLimited: Strings.commonRetry
        case .priceChanged: nil
        }
    }

    var message: String {
        switch self {
        case .minQty(let min): OrderStrings.format(OrderStrings.errorMinQty, min)
        case .dateCapacity(let date): OrderStrings.format(SendStrings.errorDateCapacity, date)
        case .dateLead(let days): OrderStrings.format(SendStrings.errorDateLead, days)
        case .dateHorizon(let max): OrderStrings.format(SendStrings.errorDateHorizon, max)
        case .districtUnserved: String(localized: OrderStrings.errorDistrictUnserved)
        case .productUnavailable: String(localized: OrderStrings.errorProductUnavailable)
        case .slotUnavailable: String(localized: OrderStrings.errorSlotUnavailable)
        case .offline: String(localized: SendStrings.errorOffline)
        case .timeout: String(localized: SendStrings.errorTimeout)
        case .server: String(localized: SendStrings.errorServer)
        case .rateLimited: String(localized: SendStrings.errorRateLimited)
        case .priceChanged: String(localized: SendStrings.priceChanged)
        }
    }
}

/// Which amounts changed after `PRICE_CHANGED`, for the highlight behind them (UI document 5.8).
struct PriceHighlight: Equatable {
    var productIDs: Set<ResourceID> = []
    var fee = false
    var total = false

    var isEmpty: Bool { productIDs.isEmpty && !fee && !total }
}
