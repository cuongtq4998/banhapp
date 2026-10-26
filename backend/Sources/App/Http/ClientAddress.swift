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
    ///
    /// Assumption: exactly one proxy sits in front of the service, as on the
    /// hosted platform (deployment.md section 3.1). With two or more proxies
    /// the last entry would be the inner proxy, not the client, and every
    /// client would share one budget. `TRUST_PROXY` must stay false when the
    /// service is reachable directly.
    ///
    /// A client may send several `X-Forwarded-For` lines; the proxy appends to
    /// the last line, so all lines are joined in order before the last entry
    /// is taken. Reading only the first line would let a forged line choose
    /// the bucket.
    static func key(for request: Request, trustProxy: Bool) -> String {
        if trustProxy,
           let last = request.headers[forwardedForHeader].joined(separator: ",").split(separator: ",").last?.trimmingCharacters(in: .whitespaces),
           !last.isEmpty {
            return last
        }
        return request.remoteAddress?.ipAddress ?? unknown
    }
}
