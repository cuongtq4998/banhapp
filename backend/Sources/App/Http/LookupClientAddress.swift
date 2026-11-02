import Vapor

extension ClientAddress {
    /// Address from the one configured proxy header, counted from the right;
    /// anything the client put further left is ignored. Empty header name:
    /// the socket peer address.
    static func lookupKey(for request: Request, headerName: String, trustedHops: Int) -> String {
        guard !headerName.isEmpty else { return request.remoteAddress?.ipAddress ?? unknown }
        let entries = request.headers[headerName].joined(separator: ",").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard entries.count >= trustedHops else { return request.remoteAddress?.ipAddress ?? unknown }
        return entries[entries.count - trustedHops]
    }
}
