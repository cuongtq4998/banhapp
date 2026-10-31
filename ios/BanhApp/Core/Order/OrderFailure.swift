import BanhContracts
import Foundation

/// Every way `POST /v1/orders` can fail, already classified for S-8 (api.md section 5, UI document
/// 5.8). Nothing here carries server text: the app shows its own copy for each case.
nonisolated enum OrderFailure: Error, Equatable, Sendable {
    /// No answer at all: the order may or may not have been stored (ADR-0008), so the retry keeps the key.
    case offline
    case timeout
    /// 422 with `fields[]`; the entries S-7 can show are mapped by `RecipientViewModel`.
    case validation([APIErrorResponse.FieldError])
    /// 409: the current prices, to replace those on the review (ADR-0010).
    case priceChanged(PriceChangedDetails)
    case minQty(Int?)
    case dateLead(days: Int?)
    case dateHorizon(maxDays: Int?)
    /// `delivery_date` is `YYYY-MM-DD`.
    case dateCapacity(deliveryDate: String?)
    case districtUnserved
    case productUnavailable([ResourceID])
    case slotUnavailable
    /// 422: the server saw this key with another body.
    case keyReused
    case rateLimited(retryAfterSeconds: Int)
    /// Anything the customer cannot fix: 5xx, a paused shop, a client defect (400, 413, 404), an unknown
    /// code, an answer that is not the contract. Shown as `ERR_SERVER`; the retry keeps the key.
    case server(APIErrorCode)

    private struct PriceEnvelope: Decodable {
        struct Error: Decodable { let details: PriceChangedDetails }
        let error: Error
    }

    /// Maps an answer that is not 2xx.
    static func from(data: Data, response: HTTPURLResponse) -> OrderFailure {
        let envelope = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        let details = envelope?.error.details ?? [:]
        switch APIErrorParser.parse(data, response: response) {
        case .rateLimited(let seconds, _):
            return .rateLimited(retryAfterSeconds: seconds)
        case .service(let code, _, _, _):
            return failure(for: code, envelope: envelope, details: details, data: data)
        case .networkUnavailable: return .offline
        case .timeout: return .timeout
        case .invalidResponse: return .server(.internalError)
        }
    }

    private static func failure(
        for code: APIErrorCode, envelope: APIErrorResponse?, details: [String: JSONValue], data: Data
    ) -> OrderFailure {
        switch code {
        case .validationFailed: return .validation(envelope?.error.fields ?? [])
        case .priceChanged:
            guard let prices = try? JSONDecoder().decode(PriceEnvelope.self, from: data) else { return .server(code) }
            return .priceChanged(prices.error.details)
        case .minQty: return .minQty(details.int("min_qty"))
        case .dateLead: return .dateLead(days: details.int("lead_days"))
        case .dateHorizon: return .dateHorizon(maxDays: details.int("max_days_ahead"))
        case .dateCapacity: return .dateCapacity(deliveryDate: details.string("delivery_date"))
        case .districtUnserved: return .districtUnserved
        case .productUnavailable: return .productUnavailable(details.resourceIDs("product_ids"))
        case .slotUnavailable: return .slotUnavailable
        case .idempotencyKeyReused: return .keyReused
        default: return .server(code)
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func int(_ key: String) -> Int? {
        if case .int(let value)? = self[key] { value } else { nil }
    }

    func string(_ key: String) -> String? {
        if case .string(let value)? = self[key] { value } else { nil }
    }

    func resourceIDs(_ key: String) -> [ResourceID] {
        guard case .array(let values)? = self[key] else { return [] }
        return values.compactMap { value in
            guard case .string(let text) = value, let uuid = UUID(uuidString: text) else { return nil }
            return ResourceID(uuid)
        }
    }
}
