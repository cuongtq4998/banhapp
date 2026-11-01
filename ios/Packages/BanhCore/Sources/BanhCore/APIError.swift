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

    /// True when the request never got an answer (the person may be offline).
    public var isConnectivity: Bool {
        switch self {
        case .networkUnavailable, .timeout: true
        case .service, .invalidResponse: false
        }
    }
}

public enum APIErrorParser {
    /// Turns a non-success response into a typed error. A body that is not the contract envelope is
    /// classified by its status only.
    public static func parse(_ data: Data, response: HTTPURLResponse) -> APIError {
        if let envelope = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return .service(
                code: envelope.error.code, messageKey: envelope.error.messageKey,
                httpStatus: response.statusCode, details: envelope.error.details
            )
        }
        var details: [String: JSONValue] = [:]
        if let header = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Int(header) {
            details["retry_after_seconds"] = .int(seconds)
        }
        return .service(code: "INTERNAL_ERROR", messageKey: "ERR_SERVER", httpStatus: response.statusCode, details: details)
    }
}
