import Vapor

/// Identifies the caller for rate limiting.
enum ClientAddress {
    static let forwardedForHeader = "X-Forwarded-For"
    /// Used when the connection exposes no address (in-process test clients).
    static let unknown = "unknown"

    /// The address that counts as "the client".
    ///
    /// Behind a trusted proxy the connection's own address is the proxy's, so
    /// the forwarded header is used. A proxy appends the address it saw to the
    /// header and keeps what the client sent, so the client can only forge the
    /// entries before the last one; the last entry is therefore the only one
    /// that can be trusted with a single proxy in front.
    static func key(for request: Request, trustProxy: Bool) -> String {
        if trustProxy,
           let forwarded = request.headers.first(name: forwardedForHeader),
           let last = forwarded.split(separator: ",").last?.trimmingCharacters(in: .whitespaces),
           !last.isEmpty {
            return last
        }
        return request.remoteAddress?.ipAddress ?? unknown
    }
}
