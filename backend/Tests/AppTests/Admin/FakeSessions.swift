import XCTVapor
import NIOConcurrencyHelpers
@testable import App

/// A clock tests can move.
final class MutableClock: WallClock, @unchecked Sendable {
    // Invariant: `instant` is only touched under `lock`.
    private let lock = NIOLock()
    private var instant: Date

    init(_ instant: Date) { self.instant = instant }
    func now() -> Date { lock.withLock { instant } }
    func advance(_ seconds: TimeInterval) { lock.withLock { instant = instant.addingTimeInterval(seconds) } }
    func set(_ date: Date) { lock.withLock { instant = date } }
}

/// Session rows held in memory, so middleware tests need no database.
final class FakeSessionLookup: AdminSessionLookup, @unchecked Sendable {
    private let lock = NIOLock()
    private var records: [UUID: AdminSessionRecord] = [:]

    func put(_ record: AdminSessionRecord) { lock.withLock { records[record.sessionID] = record } }
    func findSession(id: UUID) async throws -> AdminSessionRecord? { lock.withLock { records[id] } }
}

enum FakeSession {
    static let now = Date(timeIntervalSince1970: 1_793_577_600) // 2026-11-02 00:00 UTC

    /// A live session of `role` and its access token.
    static func make(
        role: AccountRole, now: Date = now, accessLife: TimeInterval = 300, refreshLife: TimeInterval = 86_400,
        revoked: Bool = false, active: Bool = true
    ) -> (record: AdminSessionRecord, token: SessionToken) {
        let id = UUID()
        let token = SessionToken.issue(.access, sessionID: id)
        let record = AdminSessionRecord(
            sessionID: id, accountID: UUID(), role: role, isReview: false, displayName: "Fake \(role.rawValue)",
            accessHash: token.hash, accessExpiresAt: now.addingTimeInterval(accessLife),
            refreshExpiresAt: now.addingTimeInterval(refreshLife), isRevoked: revoked, accountActive: active
        )
        return (record, token)
    }
}

/// Starts the real routes over fake sessions and a pinned clock.
class AdminRouteTestCase: XCTestCase {
    var app: Application!
    let sessions = FakeSessionLookup()
    let clock = MutableClock(FakeSession.now)

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app, config: .localWithShop())
        app.services.clock = clock
        let sessions = sessions
        app.services.repositories.makeAdminSessionLookup = { _ in sessions }
    }

    override func tearDown() async throws { try await app?.asyncShutdown() }

    func headers(_ token: SessionToken?, platform: String? = "ios", version: String? = "1.0.0") -> HTTPHeaders {
        var headers = HTTPHeaders()
        if let token { headers.bearerAuthorization = BearerAuthorization(token: token.text) }
        if let platform { headers.add(name: "X-Platform", value: platform) }
        if let version { headers.add(name: "X-App-Version", value: version) }
        return headers
    }
}
