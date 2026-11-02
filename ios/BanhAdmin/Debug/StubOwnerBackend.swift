#if DEBUG
import Foundation

/// Owner routes of the stub backend (api/07). Rules follow the server: last active district, slot or
/// cake, duplicates, the 12 cake and 30 staff limits. State lives for one launch.
final class StubOwnerBackend {
    var settings: OwnerSettings
    private var staff: [StaffAccount]
    var staffList: [StaffAccount] { staff }

    func appendStaff(_ account: StaffAccount) {
        staff.append(account)
        staff = staff.filter { $0.role == .owner } + staff.filter { $0.role == .staff }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func replaceStaff(_ account: StaffAccount) {
        if let index = staff.firstIndex(where: { $0.accountId == account.accountId }) { staff[index] = account }
    }
    private var counter = 100

    init(full: Bool) {
        settings = StubOwnerData.settings(full: full)
        staff = StubOwnerData.staff(full: full)
    }

    func handle(_ method: String, _ parts: [String], json: [String: Any], query: String, request: URLRequest) -> (Int, Data) {
        switch (method, Array(parts.dropFirst(2))) {
        case ("GET", ["settings"]): return StubReply.codable(200, settings)
        case ("PUT", ["settings", "shop"]): return saveShop(json)
        case ("GET", ["settings", "ordering", "impact"]): return impact(query)
        case ("PUT", ["settings", "ordering"]): return saveOrdering(json)
        case ("POST", ["districts"]): return addDistrict(json)
        case ("PATCH", let rest) where rest.first == "districts" && rest.count == 2: return patchDistrict(rest[1], json)
        case ("POST", ["slots"]): return addSlot(json)
        case ("PATCH", let rest) where rest.first == "slots" && rest.count == 2: return patchSlot(rest[1], json)
        case ("POST", ["cakes"]): return addCake(request)
        case ("PATCH", let rest) where rest.first == "cakes" && rest.count == 2: return patchCake(rest[1], json)
        case ("DELETE", let rest) where rest.first == "cakes" && rest.count == 2: return removeCake(rest[1])
        case ("GET", ["staff"]): return StubReply.codable(200, StaffList(accounts: staff))
        case ("POST", ["staff"]): return addStaff(json)
        case ("PATCH", let rest) where rest.first == "staff" && rest.count == 2: return patchStaff(rest[1], json)
        default: return StubReply.error(404, "NOT_FOUND", "ERR_NOT_FOUND")
        }
    }

    // MARK: Helpers

    func validation(_ problems: [(String, String)]) -> (Int, Data) {
        let fields = problems.map { ["field": $0.0, "code": $0.1, "message_key": "ERR_FIELD_INVALID"] }
        return StubReply.ok(422, [
            "error": ["code": "VALIDATION_FAILED", "message_key": "ERR_SERVER", "fields": fields, "details": [String: Any]()],
            "request_id": "7f1c1a52-0c1e-4d6c-9a54-2d7f3d6a0020",
        ])
    }

    func newID(_ prefix: String) -> String {
        counter += 1
        return String(format: "5b0c2f6a-0000-4a00-8000-%@%08d", prefix, counter)
    }

    func text(_ json: [String: Any], _ key: String) -> String? { (json[key] as? String)?.trimmingCharacters(in: .whitespaces) }

    private func saveShop(_ json: [String: Any]) -> (Int, Data) {
        var bad: [(String, String)] = []
        for key in ["name", "greeting", "phone_contact", "zalo_contact"] where (text(json, key) ?? "").isEmpty {
            bad.append((key, key.uppercased() + "_REQUIRED"))
        }
        guard bad.isEmpty else { return validation(bad) }
        settings.shop = ShopInfo(
            name: text(json, "name")!, greeting: text(json, "greeting")!,
            phoneContact: text(json, "phone_contact")!, zaloContact: text(json, "zalo_contact")!
        )
        return StubReply.codable(200, settings.shop)
    }

    private func overLimit(_ limit: Int) -> [OverLimitDate] {
        StubOwnerData.accepted.filter { $0.cakes > limit }.map { OverLimitDate(date: $0.date, cakesAccepted: $0.cakes) }
    }

    private func impact(_ query: String) -> (Int, Data) {
        let limit = URLComponents(string: "x://x?\(query)")?.queryItems?.first { $0.name == "daily_limit" }?.value.flatMap(Int.init) ?? 0
        let list = overLimit(limit)
        return StubReply.codable(200, OrderingImpact(dailyLimit: limit, overLimit: list, count: list.count))
    }

    private func saveOrdering(_ json: [String: Any]) -> (Int, Data) {
        guard let limit = json["daily_limit"] as? Int, let lead = json["lead_days"] as? Int, let min = json["min_qty"] as? Int else {
            return validation([("daily_limit", "DAILY_LIMIT_REQUIRED")])
        }
        if min > limit { return validation([("min_qty", "MIN_QTY_OUT_OF_RANGE")]) }
        settings.ordering = OrderingRules(dailyLimit: limit, leadDays: lead, minQty: min, maxDaysAhead: 30)
        let list = overLimit(limit)
        return StubReply.codable(200, OrderingSaved(dailyLimit: limit, leadDays: lead, minQty: min, maxDaysAhead: 30, overLimit: list, count: list.count))
    }
}
#endif
