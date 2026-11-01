import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// One HTTP answer as a black-box client sees it.
struct QAReply: Sendable {
    let status: Int
    let headers: [String: String]
    let data: Data
    var json: [String: Any] { (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:] }
    var text: String { String(decoding: data, as: UTF8.self) }
    var errorCode: String? { (json["error"] as? [String: Any])?["code"] as? String }
    var fieldCodes: [String] { ((json["error"] as? [String: Any])?["fields"] as? [[String: Any]])?.compactMap { $0["code"] as? String } ?? [] }
    func header(_ name: String) -> String? { headers[name.lowercased()] }
    func string(_ key: String) -> String { json[key] as? String ?? "" }
}

/// Real HTTP over a loopback socket to the in-process listener (no `app.test`).
struct QAClient: Sendable {
    let port: Int

    func send(_ method: String, _ path: String, token: String? = nil, json: Any? = nil, rawBody: Data? = nil,
              contentType: String? = nil, headers: [String: String] = [:], platform: String = "ios") async throws -> QAReply {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/\(path)")!)
        request.httpMethod = method
        request.timeoutInterval = 120
        request.setValue(platform, forHTTPHeaderField: "X-Platform")
        request.setValue("1.0.0", forHTTPHeaderField: "X-App-Version")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        var body = rawBody
        if let json { body = try JSONSerialization.data(withJSONObject: json); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, response) = body == nil ? try await Self.session.data(for: request) : try await Self.session.upload(for: request, from: body!)
        let http = response as! HTTPURLResponse // swiftlint:disable:this force_cast
        var map: [String: String] = [:]
        for (key, value) in http.allHeaderFields { map["\(key)".lowercased()] = "\(value)" }
        return QAReply(status: http.statusCode, headers: map, data: data)
    }

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 32
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    /// Writes `head` plus `body` on a raw socket and reads the status line back; lets a test
    /// announce a long Content-Length and send nothing (the server must not wait for the body).
    func rawStatus(head: String, body: Data = Data(), timeout: Int = 5) -> (status: Int?, seconds: Double) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(fd) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard connected == 0 else { return (nil, 0) }
        var tv = timeval(tv_sec: timeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        let started = Date()
        let bytes = Array(head.utf8) + Array(body)
        _ = bytes.withUnsafeBytes { Darwin.send(fd, $0.baseAddress, $0.count, 0) }
        var buffer = [UInt8](repeating: 0, count: 256)
        let count = recv(fd, &buffer, buffer.count, 0)
        let seconds = Date().timeIntervalSince(started)
        guard count > 12 else { return (nil, seconds) }
        let line = String(decoding: buffer[0..<count], as: UTF8.self)
        return (Int(line.split(separator: " ").dropFirst().first ?? ""), seconds)
    }
}
