import Foundation

/// Error envelope of every non-2xx JSON response (api.md section 1).
public struct APIErrorResponse: Codable, Equatable, Sendable {
    public struct Body: Codable, Equatable, Sendable {
        /// Machine-readable and stable. Kept a string so a client keeps
        /// decoding when a later release adds a code.
        public let code: String
        /// UI document key; clients show their own text for it.
        public let messageKey: String
        /// Present only for `VALIDATION_FAILED`.
        public let fields: [FieldError]?
        public let details: [String: JSONValue]

        public init(code: String, messageKey: String, fields: [FieldError]? = nil, details: [String: JSONValue] = [:]) {
            self.code = code
            self.messageKey = messageKey
            self.fields = fields
            self.details = details
        }

        private enum CodingKeys: String, CodingKey {
            case code
            case messageKey = "message_key"
            case fields
            case details
        }
    }

    public struct FieldError: Codable, Equatable, Sendable {
        public let field: String
        public let code: String
        public let messageKey: String

        public init(field: String, code: String, messageKey: String) {
            self.field = field
            self.code = code
            self.messageKey = messageKey
        }

        private enum CodingKeys: String, CodingKey {
            case field
            case code
            case messageKey = "message_key"
        }
    }

    public let error: Body
    public let requestID: String

    public init(error: Body, requestID: String) {
        self.error = error
        self.requestID = requestID
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case requestID = "request_id"
    }
}
