import XCTVapor
import Fluent
import FluentSQL
import BanhContracts
@testable import App

/// Shared setup of the push route tests: the owner-settings shop (one cake, one
/// slot, one district) with the recording push sender and no retry pause.
class PushDatabaseTestCase: OwnerSettingsTestCase {
    var pushSender = RecordingPushSender()
    var cakeID = UUID()
    private var orderNumber = 0

    override func setUp() async throws {
        try await super.setUp()
        pushSender = RecordingPushSender()
        app.services.push = pushSender
        app.services.pushRetryDelays = [.zero, .zero, .zero]
        let row = try await sql.raw("SELECT id FROM product WHERE shop_id = \(bind: shopID)").first()
        cakeID = try XCTUnwrap(row).decode(column: "id", as: UUID.self)
    }

    // MARK: phones

    /// A signed-in phone of `platform` (the sign-in header decides the platform of the session).
    func phoneOn(_ platform: String, of email: String) async throws -> Phone {
        let requested = try await requestCode(email)
        XCTAssertEqual(requested.status, .accepted)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: email))
        let installation = UUID()
        let reply = try await Self.send(app, .POST, "v1/auth/sessions", [
            "email": email, "code": code, "installation_id": installation.uuidString, "device_name": "Phone (\(platform))"
        ], headers: ["X-Platform": platform, "X-App-Version": "1.0.0"])
        XCTAssertEqual(reply.status, .created)
        await app.services.background.drain()
        clock.advance(31)
        return Phone(
            installationID: installation, access: reply.string("access_token"),
            refresh: reply.string("refresh_token"), deviceID: UUID(uuidString: reply.string("device_id")) ?? UUID()
        )
    }

    func register(_ phone: Phone, platform: String, token: String, environment: String? = nil, as header: String? = nil) async throws -> Reply {
        var fields = #""platform":"\#(platform)","token":"\#(token)""#
        if let environment { fields += #","apns_environment":"\#(environment)""# }
        return try await put("{\(fields)}", phone, platform: header ?? platform)
    }

    func put(_ json: String, _ phone: Phone?, platform: String = "ios") async throws -> Reply {
        let box = LockedBox<Reply?>(nil)
        var headers: HTTPHeaders = ["X-Platform": platform, "X-App-Version": "1.0.0", "Content-Type": "application/json"]
        if let phone { headers.add(name: .authorization, value: "Bearer \(phone.access)") }
        try await app.test(.PUT, "v1/admin/push-token", headers: headers, body: ByteBuffer(string: json), afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }

    func storedToken(of phone: Phone) async throws -> String? {
        let row = try await sql.raw("SELECT push_token FROM device_session WHERE id = \(bind: phone.deviceID)").first()
        return try XCTUnwrap(row).decode(column: "push_token", as: String?.self)
    }

    func storedEnvironment(of phone: Phone) async throws -> String? {
        let row = try await sql.raw("SELECT push_apns_environment FROM device_session WHERE id = \(bind: phone.deviceID)").first()
        return try XCTUnwrap(row).decode(column: "push_apns_environment", as: String?.self)
    }

    // MARK: orders

    static let customerName = "Nguyễn Thị Hương", customerAddress = "12 Ngõ Hoa Mai", customerNote = "Giao sau 5 giờ chiều"

    func orderBody(cakes: Int = 3, daysAhead: Int = 5) throws -> Data {
        orderNumber += 1
        let date = app.services.calendar.adding(days: daysAhead, to: app.services.calendar.today()).description
        let request = OrderRequestBody(
            items: [.init(productID: ResourceID(cakeID), quantity: cakes)], deliveryDate: date, slotID: ResourceID(slotID),
            customer: .init(name: Self.customerName, phone: "09\(String(format: "%08d", Int.random(in: 10_000_000..<99_999_999) + orderNumber))", address: Self.customerAddress, districtID: ResourceID(districtID)),
            note: Self.customerNote, expectedTotalVND: cakes * 50_000 + 20_000
        )
        return try JSONEncoder().encode(request)
    }

    /// `POST /v1/orders`; the background work is drained so the push has happened.
    func placeOrder(_ body: Data? = nil, key: UUID = UUID()) async throws -> Reply {
        let payload = try body ?? orderBody()
        let box = LockedBox<Reply?>(nil)
        let headers: HTTPHeaders = ["Idempotency-Key": key.uuidString.lowercased(), "X-Platform": "android", "X-App-Version": "2.1.0", "Content-Type": "application/json"]
        try await app.test(.POST, "v1/orders", headers: headers, body: ByteBuffer(data: payload), afterResponse: { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, data: Data(res.body.readableBytesView)))
        })
        return try XCTUnwrap(box.value)
    }
}
