import BanhContracts
import BanhCore
import Foundation

/// Owner-only calls (api/07 10.13 to 10.18). A staff token gets 403 on every one.
nonisolated protocol OwnerAPI: Sendable {
    func settings() async throws -> OwnerSettings
    func saveShop(_ shop: ShopInfo) async throws -> ShopInfo
    func impact(dailyLimit: Int) async throws -> OrderingImpact
    func saveOrdering(dailyLimit: Int, leadDays: Int, minQty: Int) async throws -> OrderingSaved
    func addDistrict(name: String, feeVnd: Int) async throws -> OwnerDistrict
    func updateDistrict(id: String, changes: [String: JSONValue]) async throws -> OwnerDistrict
    func addSlot(start: String, end: String) async throws -> OwnerSlot
    func updateSlot(id: String, changes: [String: JSONValue]) async throws -> OwnerSlot
    func addCake(name: String, description: String, priceVnd: Int, jpeg: Data) async throws -> Cake
    func updateCake(id: String, changes: [String: JSONValue]) async throws -> Cake
    func removeCake(id: String) async throws
    func staff() async throws -> [StaffAccount]
    func addStaff(name: String, email: String) async throws -> StaffAccount
    func setStaffActive(id: String, active: Bool) async throws -> StaffAccount
}

nonisolated struct HTTPOwnerAPI: OwnerAPI {
    let client: APIClient
    let session: SessionManager

    func call<T: Decodable & Sendable>(
        _ type: T.Type, _ method: String, _ path: String, query: [URLQueryItem] = [], json: [String: JSONValue]? = nil
    ) async throws -> T {
        let body = try json.map { try JSONEncoder().encode($0) }
        return try await session.authorized { token in
            try await client.decode(type, method, path: path, query: query, body: body, headers: ["Authorization": "Bearer \(token)"])
        }
    }

    func settings() async throws -> OwnerSettings { try await call(OwnerSettings.self, "GET", "/v1/owner/settings") }

    func saveShop(_ shop: ShopInfo) async throws -> ShopInfo {
        try await call(ShopInfo.self, "PUT", "/v1/owner/settings/shop", json: [
            "name": .string(shop.name), "greeting": .string(shop.greeting),
            "phone_contact": .string(shop.phoneContact), "zalo_contact": .string(shop.zaloContact),
        ])
    }

    func impact(dailyLimit: Int) async throws -> OrderingImpact {
        try await call(
            OrderingImpact.self, "GET", "/v1/owner/settings/ordering/impact",
            query: [URLQueryItem(name: "daily_limit", value: String(dailyLimit))]
        )
    }

    func saveOrdering(dailyLimit: Int, leadDays: Int, minQty: Int) async throws -> OrderingSaved {
        try await call(OrderingSaved.self, "PUT", "/v1/owner/settings/ordering", json: [
            "daily_limit": .int(dailyLimit), "lead_days": .int(leadDays), "min_qty": .int(minQty),
        ])
    }

    func addDistrict(name: String, feeVnd: Int) async throws -> OwnerDistrict {
        try await call(OwnerDistrict.self, "POST", "/v1/owner/districts", json: ["name": .string(name), "delivery_fee_vnd": .int(feeVnd)])
    }

    func updateDistrict(id: String, changes: [String: JSONValue]) async throws -> OwnerDistrict {
        try await call(OwnerDistrict.self, "PATCH", "/v1/owner/districts/\(id)", json: changes)
    }

    func addSlot(start: String, end: String) async throws -> OwnerSlot {
        try await call(OwnerSlot.self, "POST", "/v1/owner/slots", json: ["start": .string(start), "end": .string(end)])
    }

    func updateSlot(id: String, changes: [String: JSONValue]) async throws -> OwnerSlot {
        try await call(OwnerSlot.self, "PATCH", "/v1/owner/slots/\(id)", json: changes)
    }

    func staff() async throws -> [StaffAccount] { try await call(StaffList.self, "GET", "/v1/owner/staff").accounts }

    func addStaff(name: String, email: String) async throws -> StaffAccount {
        try await call(StaffAccount.self, "POST", "/v1/owner/staff", json: ["name": .string(name), "email": .string(email)])
    }

    func setStaffActive(id: String, active: Bool) async throws -> StaffAccount {
        try await call(StaffAccount.self, "PATCH", "/v1/owner/staff/\(id)", json: ["is_active": .bool(active)])
    }
}

extension HTTPOwnerAPI {
    /// One multipart request, atomic on the server (ADR-0025): the cake exists only when it succeeds.
    func addCake(name: String, description: String, priceVnd: Int, jpeg: Data) async throws -> Cake {
        var form = MultipartBody()
        form.addField("name", name)
        form.addField("description", description)
        form.addField("price_vnd", String(priceVnd))
        form.addFile("image", filename: "cake.jpg", mimeType: "image/jpeg", bytes: jpeg)
        let body = form.finished
        let contentType = form.contentType
        return try await session.authorized { token in
            try await client.decode(
                Cake.self, "POST", path: "/v1/owner/cakes", body: body,
                headers: ["Authorization": "Bearer \(token)", "Content-Type": contentType]
            )
        }
    }

    func updateCake(id: String, changes: [String: JSONValue]) async throws -> Cake {
        try await call(Cake.self, "PATCH", "/v1/owner/cakes/\(id)", json: changes)
    }

    func removeCake(id: String) async throws {
        _ = try await session.authorized { token in
            try await client.send("DELETE", path: "/v1/owner/cakes/\(id)", headers: ["Authorization": "Bearer \(token)"])
        }
    }
}
