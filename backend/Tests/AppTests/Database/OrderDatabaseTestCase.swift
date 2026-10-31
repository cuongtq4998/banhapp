import XCTVapor
import Fluent
import FluentSQL
import BanhContracts
@testable import App

/// Base for the order tests that commit to a real PostgreSQL (the order
/// transaction opens its own, so the rolled-back wrapper of `DatabaseTestCase`
/// cannot be used, and concurrency needs real connections). Every test seeds
/// its own fake shop, so tests do not see each other's rows; the rows stay in
/// the throwaway database. Skipped unless `DATABASE_MIGRATION_URL` is set.
class OrderDatabaseTestCase: XCTestCase {
    struct Seed {
        let shopID: UUID
        let productID = UUID()
        let districtID = UUID()
        let slotID = UUID()
    }

    struct Answer: Sendable {
        let status: HTTPResponseStatus
        let replayHeader: String?
        let body: String
    }

    var app: Application!
    var sql: any SQLDatabase { app.db as! any SQLDatabase }

    /// Starts the real application on the database with a pinned clock (2026-11-02) and a fresh shop.
    func start(dailyLimit: Int, price: Int = 50_000, orders: OrderPolicy = OrderPolicy(perAddressPerHour: 10_000)) async throws -> Seed {
        let url = ProcessInfo.processInfo.environment[AppConfig.Key.databaseMigrationURL] ?? ""
        try XCTSkipIf(url.isEmpty, "\(AppConfig.Key.databaseMigrationURL) is not set; database tests skipped")
        let seed = Seed(shopID: UUID())
        let migrator = try await Application.make(.testing)
        try configureMigrator(migrator, config: MigrationConfig(stage: .local, databaseMigrationURL: url))
        try await migrator.autoMigrate()
        try await migrator.asyncShutdown()

        app = try await Application.make(.testing)
        let config = AppConfig(stage: .local, port: 8080, databaseURL: url, databasePoolMax: 12, shopID: seed.shopID, orders: orders)
        try await configure(app, config: config)
        app.services.clock = AvailabilityTestData.clock
        try await insertShop(seed, dailyLimit: dailyLimit, price: price)
        return seed
    }

    override func tearDown() async throws {
        try await app?.asyncShutdown()
        app = nil
    }

    private func insertShop(_ seed: Seed, dailyLimit: Int, price: Int) async throws {
        try await sql.raw("""
            INSERT INTO shop (id, name, greeting, phone_contact, zalo_contact, is_sample)
            VALUES (\(bind: seed.shopID), 'Test shop', 'Hello', '+84900000000', 'zalo-test', true)
            """).run()
        try await sql.raw("""
            INSERT INTO shop_setting (shop_id, daily_limit, lead_days, min_qty, max_days_ahead, max_qty_per_cake, is_sample)
            VALUES (\(bind: seed.shopID), \(bind: dailyLimit), 2, 2, 30, 99, true)
            """).run()
        try await sql.raw("""
            INSERT INTO product (id, shop_id, slug, name, description, price_vnd, image_path, is_sample)
            VALUES (\(bind: seed.productID), \(bind: seed.shopID), 'banana', 'Bánh chuối', 'Test', \(bind: price), 'images/banana.png', true)
            """).run()
        try await sql.raw("""
            INSERT INTO district (id, shop_id, name, delivery_fee_vnd, is_sample)
            VALUES (\(bind: seed.districtID), \(bind: seed.shopID), 'Quận 1', 20000, true)
            """).run()
        try await sql.raw("""
            INSERT INTO delivery_slot (id, shop_id, start_time, end_time, is_sample)
            VALUES (\(bind: seed.slotID), \(bind: seed.shopID), '08:00', '10:00', true)
            """).run()
    }

    func body(_ seed: Seed, cakes: Int = 2, phone: String = "0900000000", date: String = "2026-11-10", total: Int? = nil) throws -> Data {
        let request = OrderRequestBody(
            items: [.init(productID: ResourceID(seed.productID), quantity: cakes)], deliveryDate: date, slotID: ResourceID(seed.slotID),
            customer: .init(name: "Nguyễn Văn A", phone: phone, address: "1 Test Street", districtID: ResourceID(seed.districtID)),
            note: "Ít đường", expectedTotalVND: total ?? cakes * 50_000 + 20_000
        )
        return try JSONEncoder().encode(request)
    }

    func send(_ payload: Data, key: UUID = UUID()) async throws -> Answer {
        try await Self.send(app, payload, key: key)
    }

    /// Static, so parallel tasks capture only the (Sendable) application.
    static func send(_ app: Application, _ payload: Data, key: UUID) async throws -> Answer {
        let headers: HTTPHeaders = ["Idempotency-Key": key.uuidString.lowercased(), "X-Platform": "android", "X-App-Version": "2.1.0", "Content-Type": "application/json"]
        let box = LockedBox(Answer(status: .internalServerError, replayHeader: nil, body: ""))
        try await app.test(.POST, "v1/orders", headers: headers, body: ByteBuffer(data: payload), afterResponse: { res async throws in
            box.set(Answer(status: res.status, replayHeader: res.headers.first(name: "Idempotent-Replay"), body: res.body.string))
        })
        return box.value
    }

    func count(_ query: SQLQueryString) async throws -> Int {
        let row = try await sql.raw(query).first()
        return try XCTUnwrap(row).decode(column: "n", as: Int.self)
    }

    func cakes(_ seed: Seed, date: String = "2026-11-10") async throws -> Int {
        try await count("SELECT coalesce(sum(cakes_accepted), 0)::int AS n FROM day_load WHERE shop_id = \(bind: seed.shopID) AND delivery_date = \(bind: date)::date")
    }

    func orderCount(_ seed: Seed) async throws -> Int {
        try await count("SELECT count(*)::int AS n FROM customer_order WHERE shop_id = \(bind: seed.shopID)")
    }

    func errorCode(_ answer: Answer) throws -> String {
        try JSONDecoder().decode(APIErrorResponse.self, from: Data(answer.body.utf8)).error.code
    }
}
