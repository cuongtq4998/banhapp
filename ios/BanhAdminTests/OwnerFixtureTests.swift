import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

/// The owner fixtures of contracts/fixtures/admin decode into the owner models and error parser.
struct OwnerFixtureTests {
    private func body(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "contracts/fixtures/admin/\(name).json")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try JSONSerialization.data(withJSONObject: root["body"] ?? root)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try APIClient.decoder.decode(type, from: body(name))
    }

    @Test func ownerFixturesDecode() throws {
        let settings = try decode(OwnerSettings.self, "owner-settings")
        #expect(settings.cakes.first?.priceVnd == 150_000 && settings.slots.first?.start == "08:00" && settings.staffCountMax == 30)
        #expect(try decode(Cake.self, "owner-cake-created").isActive)
        #expect(try decode(Cake.self, "owner-cake-updated").isActive == false)
        #expect(try decode(OwnerDistrict.self, "owner-district-created").deliveryFeeVnd == 20_000)
        #expect(try decode(OwnerSlot.self, "owner-slot-created").end == "10:00")
        #expect(try decode(ShopInfo.self, "owner-shop-saved").phoneContact == "+84900000000")
        #expect(try decode(OrderingImpact.self, "owner-ordering-impact").overLimit.first?.cakesAccepted == 98)
        #expect(try decode(OrderingSaved.self, "owner-ordering-saved").count == 1)
        #expect(try decode(StaffList.self, "owner-staff-list").accounts.first?.role == .owner)
        #expect(try decode(StaffAccount.self, "owner-staff-deactivated").isActive == false)
    }

    @Test func ownerErrorsParseWithTheirCodesAndFields() throws {
        for (name, code) in [
            ("error-cake-limit-reached", "CAKE_LIMIT_REACHED"), ("error-last-active-cake", "LAST_ACTIVE_CAKE"),
            ("error-last-active-district", "LAST_ACTIVE_DISTRICT"), ("error-last-active-slot", "LAST_ACTIVE_SLOT"),
            ("error-slot-duplicate", "SLOT_DUPLICATE"), ("error-email-taken", "EMAIL_TAKEN"),
            ("error-staff-limit-reached", "STAFF_LIMIT_REACHED"), ("error-owner-protected", "OWNER_PROTECTED"),
            ("error-image-too-large", "IMAGE_TOO_LARGE"),
        ] {
            let status = code == "IMAGE_TOO_LARGE" ? 413 : (code == "SLOT_DUPLICATE" ? 422 : 409)
            let response = HTTPURLResponse(url: URL(string: "http://x.invalid")!, statusCode: status, httpVersion: nil, headerFields: nil)!
            #expect(APIErrorParser.parse(try body(name), response: response).code == code, "\(name)")
        }
        let response = HTTPURLResponse(url: URL(string: "http://x.invalid")!, statusCode: 422, httpVersion: nil, headerFields: nil)!
        let taken = APIErrorParser.parse(try body("error-cake-name-taken"), response: response)
        #expect(taken.fieldProblems == [FieldProblem(field: "name", code: "NAME_TAKEN")])
        #expect(APIErrorParser.parse(try body("error-cake-validation"), response: response).fieldProblems.count == 3)
    }

    @Test func meCarriesTheEmailWhenTheServerSendsIt() throws {
        let json = #"{"account":{"name":"A","role":"staff"},"email":"a@example.com","device_id":"d","server_date":"2026-11-02"}"#
        #expect(try APIClient.decoder.decode(MeResponse.self, from: Data(json.utf8)).email == "a@example.com")
        let old = #"{"account":{"name":"A","role":"staff"},"device_id":"d","server_date":"2026-11-02"}"#
        #expect(try APIClient.decoder.decode(MeResponse.self, from: Data(old.utf8)).email == nil)
    }
}
