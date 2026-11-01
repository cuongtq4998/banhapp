#if DEBUG
import BanhCore
import Foundation

/// Builds the answers of `StubAdminTransport` in the shapes of docs/system/api/05 and 06.
enum StubReply {
    static func ok(_ status: Int, _ object: [String: Any]) -> (Int, Data) {
        (status, (try? JSONSerialization.data(withJSONObject: object)) ?? Data())
    }

    static func codable<T: Encodable>(_ status: Int, _ value: T) -> (Int, Data) {
        (status, (try? APIClient.encoder.encode(value)) ?? Data())
    }

    /// An encodable value as a JSON object, to nest it in an error `details`.
    static func object<T: Encodable>(_ value: T) -> Any {
        let data = (try? APIClient.encoder.encode(value)) ?? Data()
        return (try? JSONSerialization.jsonObject(with: data)) ?? [:]
    }

    static func error(_ status: Int, _ code: String, _ key: String, details: [String: Any] = [:]) -> (Int, Data) {
        ok(status, [
            "error": ["code": code, "message_key": key, "details": details],
            "request_id": "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0020",
        ])
    }
}
#endif
