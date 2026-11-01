import BanhContracts
import Foundation

/// Every way a call to the backend can fail, so callers branch on cases and never on message text.
public enum APIError: Error, Equatable, Sendable {
    case networkUnavailable
    case timeout
    /// The server answered with the contract error body (api.md section 1). `code` is the wire code.
    case service(code: String, messageKey: String, httpStatus: Int, details: [String: JSONValue])
    /// A success status with a body that does not match the contract.
    case invalidResponse

    public var code: String? {
        if case .service(let code, _, _, _) = self { code } else { nil }
    }

    public var httpStatus: Int? {
        if case .service(_, _, let status, _) = self { status } else { nil }
    }

    /// `details.retry_after_seconds` of a 429 answer.
    public var retryAfterSeconds: Int? {
        if case .service(_, _, _, let details) = self, case .int(let seconds)? = details["retry_after_seconds"] {
            seconds
        } else {
            nil
        }
    }

    /// The entries of `fields[]` of a 422 `VALIDATION_FAILED` answer (`field`, `code`), in server order.
    public var fieldProblems: [FieldProblem] {
        guard case .service(_, _, _, let details) = self, case .array(let items)? = details[APIErrorParser.fieldsKey] else { return [] }
        return items.compactMap { item in
            guard case .object(let entry) = item, case .string(let field)? = entry["field"], case .string(let code)? = entry["code"]
            else { return nil }
            return FieldProblem(field: field, code: code)
        }
    }

    /// True when the request never got an answer (the person may be offline).
    public var isConnectivity: Bool {
        switch self {
        case .networkUnavailable, .timeout: true
        case .service, .invalidResponse: false
        }
    }
}

public struct FieldProblem: Equatable, Sendable {
    public let field: String
    public let code: String

    public init(field: String, code: String) {
        self.field = field
        self.code = code
    }
}

public enum APIErrorParser {
    /// Key under which `fields[]` is kept inside `details` (the envelope has no key of this name).
    public static let fieldsKey = "_fields"

    /// Turns a non-success response into a typed error. A body that is not the contract envelope is
    /// classified by its status only.
    public static func parse(_ data: Data, response: HTTPURLResponse) -> APIError {
        if let envelope = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            var details = envelope.error.details
            if let fields = envelope.error.fields {
                details[fieldsKey] = .array(fields.map { .object(["field": .string($0.field), "code": .string($0.code)]) })
            }
            return .service(
                code: envelope.error.code, messageKey: envelope.error.messageKey,
                httpStatus: response.statusCode, details: details
            )
        }
        var details: [String: JSONValue] = [:]
        if let header = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Int(header) {
            details["retry_after_seconds"] = .int(seconds)
        }
        return .service(code: "INTERNAL_ERROR", messageKey: "ERR_SERVER", httpStatus: response.statusCode, details: details)
    }
}
