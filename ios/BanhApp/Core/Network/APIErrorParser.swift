import BanhContracts
import Foundation

/// Turns a non-success response into a typed error. A body that is not the contract envelope (for
/// example an answer from a proxy in front of the host) is classified by its status only.
nonisolated enum APIErrorParser {
    static let defaultRetryAfterSeconds = 60
    static let fallbackMessageKey = "ERR_SERVER"

    private static let retryAfterDetail = "retry_after_seconds"
    private static let retryAfterHeader = "Retry-After"
    private static let httpTooManyRequests = 429
    private static let httpServiceUnavailable = 503

    static func parse(_ data: Data, response: HTTPURLResponse) -> APIError {
        let envelope = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        let code = envelope.map { APIErrorCode(wire: $0.error.code) } ?? code(forStatus: response.statusCode)
        let requestID = envelope?.requestID

        if code == .rateLimited {
            return .rateLimited(retryAfterSeconds: retryAfterSeconds(envelope, response), requestID: requestID)
        }
        return .service(
            code: code,
            messageKey: envelope?.error.messageKey ?? fallbackMessageKey,
            httpStatus: response.statusCode,
            requestID: requestID
        )
    }

    // The body detail wins because it is the contract; the header covers a body that did not decode.
    private static func retryAfterSeconds(_ envelope: APIErrorResponse?, _ response: HTTPURLResponse) -> Int {
        if case .int(let seconds)? = envelope?.error.details[retryAfterDetail] { return seconds }
        let header = response.value(forHTTPHeaderField: retryAfterHeader)
        return header.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? defaultRetryAfterSeconds
    }

    private static func code(forStatus status: Int) -> APIErrorCode {
        switch status {
        case httpTooManyRequests: .rateLimited
        case httpServiceUnavailable: .serviceUnavailable
        default: .internalError
        }
    }
}
