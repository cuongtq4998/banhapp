import XCTVapor
import Fluent
import FluentSQL
@testable import App

/// What a test saw of one HTTP exchange.
struct Reply: Sendable {
    let status: HTTPStatus
    let headers: HTTPHeaders
    let data: Data

    var json: [String: Any] { (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:] }
    var errorCode: String? { (json["error"] as? [String: Any])?["code"] as? String }
    var retryAfter: Int? { headers.first(name: .retryAfter).flatMap { Int($0) } }
    func string(_ key: String) -> String { json[key] as? String ?? "" }
}

struct Phone: Sendable {
    let installationID: UUID
    var access: String
    var refresh: String
    let deviceID: UUID
}

/// Real routes over a real PostgreSQL (skipped without `DATABASE_MIGRATION_URL`),
/// a movable clock and the recording mail sink. Every test has its own shop and
/// its own addresses, and runs on its own day, so nothing leaks between tests.
class AdminDatabaseTestCase: XCTestCase {
    var app: Application!
    var shopID = UUID()
    var mail = RecordingEmailSender()
    var clock = MutableClock(Date())
    let pepper = String(repeating: "t", count: 32)

    override func setUp() async throws {
        let url = ProcessInfo.processInfo.environment[AppConfig.Key.databaseMigrationURL] ?? ""
        try XCTSkipIf(url.isEmpty, "\(AppConfig.Key.databaseMigrationURL) is not set; database tests skipped")
        shopID = UUID()
        // 03:00 UTC on a day no other test run uses (the daily cap counts per UTC day).
        let day = Int.random(in: 0..<20_000)
        clock = MutableClock(Date(timeIntervalSince1970: 1_924_995_600 + TimeInterval(day) * 86_400))
        app = try await Application.make(.testing)
        let admin = AdminAuthConfig(pepper: pepper, emailProvider: .recording, emailMaxPerDay: 1_000_000)
        try await configure(app, config: AppConfig(stage: .local, port: 8080, databaseURL: url, shopID: shopID, admin: admin))
        for file in try MigrationFiles.load(from: TestPaths.migrations) { app.migrations.add(file) }
        try await app.autoMigrate()
        app.services.clock = clock
        app.services.mailRetryDelay = .zero
        mail = try XCTUnwrap(app.services.email as? RecordingEmailSender)
        try await run("INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact) VALUES (\(bind: shopID), 'Test', 'Hi', '+84900000000', 'zalo')")
    }

    override func tearDown() async throws { try await app?.asyncShutdown() }

    // MARK: database

    var sql: any SQLDatabase { app.db as! any SQLDatabase } // swiftlint:disable:this force_cast

    func run(_ query: SQLQueryString) async throws { try await sql.raw(query).run() }

    func count(_ query: SQLQueryString) async throws -> Int {
        try await sql.raw(query).first()?.decode(column: "n", as: Int.self) ?? -1
    }

    @discardableResult
    func addAccount(_ role: AccountRole, _ name: String = "Nhan Vien", active: Bool = true) async throws -> (id: UUID, email: String) {
        let id = UUID(), email = "\(name.lowercased().replacingOccurrences(of: " ", with: "."))\(id.uuidString.prefix(8).lowercased())@example.com"
        try await run("INSERT INTO account (id, shop_id, role, email, display_name, is_active) VALUES (\(bind: id), \(bind: shopID), \(bind: role.rawValue), \(bind: email), \(bind: name), \(bind: active))")
        return (id, email)
    }

    // MARK: http

    func send(_ method: HTTPMethod, _ path: String, _ body: [String: String]? = nil, headers: HTTPHeaders = [:]) async throws -> Reply {
        try await Self.send(app, method, path, body, headers: headers)
    }

    /// Static so parallel tasks can call it without capturing the test case.
    static func send(_ app: Application, _ method: HTTPMethod, _ path: String, _ body: [String: String]? = nil, headers: HTTPHeaders = [:]) async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        try await app.test(method, path, headers: headers, beforeRequest: { req async throws in
            if let body { try req.content.encode(body, as: .json) }
        }, afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    static func signIn(_ app: Application, _ email: String, _ code: String, installation: UUID = UUID(), device: String = "iPhone (iOS 17.5)") async throws -> Reply {
        try await send(app, .POST, "v1/auth/sessions", [
            "email": email, "code": code, "installation_id": installation.uuidString, "device_name": device
        ], headers: ["X-Platform": "ios", "X-App-Version": "1.0.0"])
    }

    func requestCode(_ email: String) async throws -> Reply {
        try await send(.POST, "v1/auth/code-requests", ["email": email])
    }

    func signIn(_ email: String, _ code: String, installation: UUID = UUID(), device: String = "iPhone (iOS 17.5)") async throws -> Reply {
        try await Self.signIn(app, email, code, installation: installation, device: device)
    }

    /// Request a code and use it; the phone is signed in.
    func signedIn(_ email: String, installation: UUID = UUID()) async throws -> Phone {
        let requested = try await requestCode(email)
        XCTAssertEqual(requested.status, .accepted)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: email))
        let reply = try await signIn(email, code, installation: installation)
        XCTAssertEqual(reply.status, .created, String(decoding: reply.data, as: UTF8.self))
        await app.services.background.drain()
        clock.advance(31) // the next code request for this address is allowed
        return Phone(
            installationID: installation, access: reply.string("access_token"),
            refresh: reply.string("refresh_token"), deviceID: UUID(uuidString: reply.string("device_id")) ?? UUID()
        )
    }

    func refresh(_ token: String) async throws -> Reply {
        try await send(.POST, "v1/auth/refresh", ["refresh_token": token])
    }

    func authed(_ method: HTTPMethod, _ path: String, _ access: String) async throws -> Reply {
        try await send(method, path, headers: ["Authorization": "Bearer \(access)", "X-Platform": "ios", "X-App-Version": "1.0.0"])
    }
}
