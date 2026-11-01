import BanhContracts
import BanhCore
import Foundation
@testable import BanhAdmin

/// Owner API fake: answers from `settingsResult` and the `results` of each call, and records the calls.
final class FakeOwnerAPI: OwnerAPI, @unchecked Sendable {
    var settingsResult: Result<OwnerSettings, Error> = .success(TestOwner.settings())
    var impactResult: Result<OrderingImpact, Error> = .success(OrderingImpact(dailyLimit: 0, overLimit: [], count: 0))
    var savedOrdering: Result<OrderingSaved, Error> = .success(TestOwner.saved([]))
    /// What every write call throws when set.
    var writeError: Error?
    var staffResult: Result<[StaffAccount], Error> = .success(TestOwner.staff())
    private(set) var calls: [String] = []
    private(set) var lastChanges: [String: JSONValue] = [:]
    private(set) var lastJPEG: Data?
    private(set) var lastShop: ShopInfo?

    private func record(_ call: String) throws {
        calls.append(call)
        if let writeError, !call.hasPrefix("GET") { throw writeError }
    }

    func settings() async throws -> OwnerSettings { try settingsResult.get() }
    func staff() async throws -> [StaffAccount] { try staffResult.get() }

    func saveShop(_ shop: ShopInfo) async throws -> ShopInfo {
        try record("PUT shop")
        lastShop = shop
        return shop
    }

    func impact(dailyLimit: Int) async throws -> OrderingImpact {
        calls.append("GET impact \(dailyLimit)")
        return try impactResult.get()
    }

    func saveOrdering(dailyLimit: Int, leadDays: Int, minQty: Int) async throws -> OrderingSaved {
        try record("PUT ordering \(dailyLimit) \(leadDays) \(minQty)")
        return try savedOrdering.get()
    }

    func addDistrict(name: String, feeVnd: Int) async throws -> OwnerDistrict {
        try record("POST district \(name) \(feeVnd)")
        return OwnerDistrict(districtId: "d9", name: name, deliveryFeeVnd: feeVnd, isActive: true)
    }

    func updateDistrict(id: String, changes: [String: JSONValue]) async throws -> OwnerDistrict {
        try record("PATCH district \(id)")
        lastChanges = changes
        return TestOwner.settings().districts[0]
    }

    func addSlot(start: String, end: String) async throws -> OwnerSlot {
        try record("POST slot \(start) \(end)")
        return OwnerSlot(slotId: "s9", start: start, end: end, isActive: true)
    }

    func updateSlot(id: String, changes: [String: JSONValue]) async throws -> OwnerSlot {
        try record("PATCH slot \(id)")
        lastChanges = changes
        return TestOwner.settings().slots[0]
    }

    func addCake(name: String, description: String, priceVnd: Int, jpeg: Data) async throws -> Cake {
        try record("POST cake \(name) \(priceVnd)")
        lastJPEG = jpeg
        return TestOwner.settings().cakes[0]
    }

    func updateCake(id: String, changes: [String: JSONValue]) async throws -> Cake {
        try record("PATCH cake \(id)")
        lastChanges = changes
        return TestOwner.settings().cakes[0]
    }

    func removeCake(id: String) async throws { try record("DELETE cake \(id)") }

    func addStaff(name: String, email: String) async throws -> StaffAccount {
        try record("POST staff \(email)")
        return StaffAccount(accountId: "a9", name: name, email: email, role: .staff, isActive: true)
    }

    func setStaffActive(id: String, active: Bool) async throws -> StaffAccount {
        try record("PATCH staff \(id) \(active)")
        return StaffAccount(accountId: id, name: "X", email: "x@example.com", role: .staff, isActive: active)
    }
}

enum TestOwner {
    static func cake(_ id: String, _ name: String, active: Bool = true) -> Cake {
        Cake(cakeId: id, name: name, description: "Banh", priceVnd: 150_000, isActive: active, imageUrl: "/assets/cakes/\(id)?v=0a1b2c3d")
    }

    static func settings(cakes: [Cake]? = nil) -> OwnerSettings {
        OwnerSettings(
            shop: ShopInfo(name: "Tiem Banh Mau", greeting: "Xin chao", phoneContact: "+84900000000", zaloContact: "zalo.me/tiembanhmau"),
            ordering: OrderingRules(dailyLimit: 60, leadDays: 2, minQty: 2, maxDaysAhead: 30),
            cakes: cakes ?? [cake("c1", "Banh Mau"), cake("c2", "Banh Chuoi", active: false)],
            districts: [OwnerDistrict(districtId: "d1", name: "Quan An Phu", deliveryFeeVnd: 20_000, isActive: true)],
            slots: [OwnerSlot(slotId: "s1", start: "08:00", end: "10:00", isActive: true)],
            cakeCountMax: 12, staffCountMax: 30
        )
    }

    static func saved(_ over: [OverLimitDate]) -> OrderingSaved {
        OrderingSaved(dailyLimit: 40, leadDays: 2, minQty: 2, maxDaysAhead: 30, overLimit: over, count: over.count)
    }

    static func staff() -> [StaffAccount] {
        [
            StaffAccount(accountId: "a1", name: "Chu Mau", email: "chu@example.com", role: .owner, isActive: true),
            StaffAccount(accountId: "a2", name: "Nhan Vien A", email: "a@example.com", role: .staff, isActive: true),
        ]
    }

    static func problem(_ status: Int, _ code: String, fields: [FieldProblem] = []) -> APIError {
        var details: [String: JSONValue] = [:]
        if !fields.isEmpty {
            details[APIErrorParser.fieldsKey] = .array(fields.map { .object(["field": .string($0.field), "code": .string($0.code)]) })
        }
        return .service(code: code, messageKey: "K", httpStatus: status, details: details)
    }
}

/// Collects the toasts and the "done" calls of a model.
final class Sink: @unchecked Sendable {
    private(set) var toasts: [String] = []
    private(set) var doneCount = 0
    func flash(_ text: String) { toasts.append(text) }
    func done() { doneCount += 1 }
}
