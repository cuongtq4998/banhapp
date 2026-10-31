import Foundation
@testable import AppUnderTest

enum Slice1 {
    static let catalogPath = "v1/catalog"
    static let dbVariable = "DATABASE_MIGRATION_URL"
    /// Tests that change rows (price, activity, order) need this on top of the
    /// throwaway database rule of deployment.md section 5.
    static let mutationVariable = "QA_ALLOW_DB_MUTATION"
    static let realClientVariable = "QA_BASE_URL"

    static var databaseURL: String? {
        let v = ProcessInfo.processInfo.environment[dbVariable]
        return (v?.isEmpty ?? true) ? nil : v
    }

    static var mutationAllowed: Bool { ProcessInfo.processInfo.environment[mutationVariable] == "1" }

    /// Fake shop values of backend/db/seed/sample.sql (ADR-0013). Kept as
    /// literals on purpose: a change of the sample data must be a visible
    /// change of the expected data (TC-S1-13).
    enum Seed {
        static let shopID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        static let shopName = "Tiệm Bánh An Nhiên"
        static let greeting = "Bánh làm thủ công, giao tận nơi."
        static let phone = "+84900000000"
        static let zalo = "84900000000"
        static let settings: [String: Int] = [
            "min_qty": 2, "lead_days": 2, "max_days_ahead": 30, "max_qty_per_cake": 99, "note_max_length": 200
        ]
        /// slug, name, description, price, product id
        static let products: [(String, String, String, Int, String)] = [
            ("banana", "Bánh chuối", "Bánh chuối nướng thơm béo.", 35000, "00000000-0000-4000-8000-000000000011"),
            ("mung-bean-pork-fat", "Bánh đậu xanh nhân mỡ", "Đậu xanh nghiền mịn, nhân mỡ.", 45000, "00000000-0000-4000-8000-000000000012"),
            ("mung-bean-vegetarian", "Bánh đậu xanh chay", "Đậu xanh nghiền mịn, không nhân mỡ.", 45000, "00000000-0000-4000-8000-000000000013"),
            ("mung-bean-egg-yolk-pork-fat", "Bánh đậu xanh trứng mỡ", "Đậu xanh, trứng muối và mỡ.", 55000, "00000000-0000-4000-8000-000000000014")
        ]
        static let districts: [(String, Int)] = [("Quận 1", 15000), ("Quận 3", 15000), ("Quận 5", 20000), ("Phú Nhuận", 20000), ("Bình Thạnh", 25000)]
        static let slots: [(String, String)] = [("08:00", "10:00"), ("10:00", "12:00"), ("14:00", "16:00"), ("16:00", "18:00")]
    }

    /// Words that must never show in any customer-visible response value or key
    /// (AC-27 payment, AC-29 sample markers). Matched on word boundaries,
    /// case-insensitive, after removing diacritics.
    static let forbiddenWords = [
        "sample", "demo", "test", "payment", "pay", "paid", "bank", "momo", "zalopay", "vnpay", "qr",
        "thanh toan", "chuyen khoan", "tien mat", "is_sample", "daily_limit", "remaining"
    ]

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
            .lowercased()
    }

    static func forbiddenHits(in texts: [String]) -> [String] {
        var hits: [String] = []
        for text in texts {
            let folded = fold(text)
            for word in forbiddenWords {
                let pattern = "(^|[^a-z0-9])" + NSRegularExpression.escapedPattern(for: word) + "($|[^a-z0-9])"
                if folded.range(of: pattern, options: .regularExpression) != nil { hits.append("\(word) in \(text)") }
            }
        }
        return hits
    }

    private static func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: .regularExpression) != nil
    }

    private static let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
    private static let hhmm = "^([01][0-9]|2[0-3]):[0-5][0-9]$"

    /// Contract check of api.md section 3 and 4.1. Returns every problem found
    /// (empty when the document is a valid catalog). Used for live responses
    /// and for the fixtures in contracts/fixtures.
    static func shapeProblems(_ root: J, productCount: Int = 4, minDistricts: Int = 1, minSlots: Int = 1) -> [String] {
        var p: [String] = []
        func keys(_ j: J?, _ expected: Set<String>, _ label: String) {
            guard let o = j?.object else { p.append("\(label) is not an object"); return }
            let actual = Set(o.keys)
            if actual != expected { p.append("\(label) keys \(actual.sorted()) != \(expected.sorted())") }
        }
        keys(root, ["server_date", "shop", "settings", "products", "districts", "slots"], "root")
        if let d = root["server_date"]?.string {
            if !matches(d, "^\\d{4}-\\d{2}-\\d{2}$") { p.append("server_date format \(d)") }
        } else { p.append("server_date missing or not a string") }

        keys(root["shop"], ["name", "greeting", "phone_contact", "zalo_contact"], "shop")
        if let phone = root["shop"]?["phone_contact"]?.string, !matches(phone, "^\\+[1-9][0-9]{7,14}$") { p.append("phone_contact not E.164: \(phone)") }
        if let zalo = root["shop"]?["zalo_contact"]?.string, zalo.count < 3 { p.append("zalo_contact too short") }

        keys(root["settings"], Set(Seed.settings.keys), "settings")
        for key in Seed.settings.keys {
            guard let v = root["settings"]?[key] else { continue }
            if v.int == nil { p.append("settings.\(key) is not an integer") }
        }
        if let n = root["settings"]?["note_max_length"]?.int, n != 200 { p.append("note_max_length \(n) != 200") }
        if let n = root["settings"]?["max_qty_per_cake"]?.int, !(1...99).contains(n) { p.append("max_qty_per_cake \(n)") }
        if let n = root["settings"]?["min_qty"]?.int, n < 1 { p.append("min_qty \(n)") }

        func list(_ name: String, _ expectedKeys: Set<String>, _ minCount: Int) -> [J] {
            guard let items = root[name]?.array else { p.append("\(name) is not an array"); return [] }
            if items.count < minCount { p.append("\(name) has \(items.count) entries, need at least \(minCount)") }
            for (i, item) in items.enumerated() { keys(item, expectedKeys, "\(name)[\(i)]") }
            return items
        }
        let products = list("products", ["product_id", "slug", "name", "description", "price_vnd", "image_url"], productCount)
        if products.count != productCount { p.append("products count \(products.count) != \(productCount)") }
        for (i, item) in products.enumerated() {
            if let id = item["product_id"]?.string, !matches(id, uuidPattern) { p.append("products[\(i)].product_id not uuid") }
            if let slug = item["slug"]?.string, !matches(slug, "^[a-z0-9-]{1,40}$") { p.append("products[\(i)].slug \(slug)") }
            if item["price_vnd"]?.int == nil { p.append("products[\(i)].price_vnd not an integer") }
            if let price = item["price_vnd"]?.int, price < 0 { p.append("products[\(i)].price_vnd negative") }
            if let url = item["image_url"]?.string {
                if !(url.hasPrefix("/") || url.hasPrefix("https://")) { p.append("products[\(i)].image_url neither absolute path nor https: \(url)") }
                if url.contains("..") || url.contains("\\") { p.append("products[\(i)].image_url traversal: \(url)") }
            }
        }
        let districts = list("districts", ["district_id", "name", "delivery_fee_vnd"], minDistricts)
        for (i, item) in districts.enumerated() {
            if let id = item["district_id"]?.string, !matches(id, uuidPattern) { p.append("districts[\(i)].district_id not uuid") }
            if item["delivery_fee_vnd"]?.int == nil { p.append("districts[\(i)].delivery_fee_vnd not an integer") }
        }
        let slots = list("slots", ["slot_id", "start", "end"], minSlots)
        for (i, item) in slots.enumerated() {
            if let id = item["slot_id"]?.string, !matches(id, uuidPattern) { p.append("slots[\(i)].slot_id not uuid") }
            guard let s = item["start"]?.string, let e = item["end"]?.string else { continue }
            if !matches(s, hhmm) || !matches(e, hhmm) { p.append("slots[\(i)] time format \(s)-\(e)") }
            else if s >= e { p.append("slots[\(i)] end not after start") }
        }
        for (name, ids) in [("products", products.compactMap { $0["product_id"]?.string }),
                            ("districts", districts.compactMap { $0["district_id"]?.string }),
                            ("slots", slots.compactMap { $0["slot_id"]?.string })] where Set(ids).count != ids.count {
            p.append("\(name) ids are not unique")
        }
        for text in root.allText {
            if text != text.precomposedStringWithCanonicalMapping { p.append("not NFC: \(text)") }
            if text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) { p.append("control character in \(text.debugDescription)") }
            if text.contains("\u{FFFD}") { p.append("replacement character in \(text)") }
        }
        return p
    }

    /// Public envelope check (api.md section 1) for a non-2xx reply.
    static func envelopeProblems(_ reply: Reply, code: String, messageKey: String) -> [String] {
        var p: [String] = []
        guard let root = reply.json, let error = root["error"] else { return ["body is not an error envelope: \(reply.text.prefix(120))"] }
        if error["code"]?.string != code { p.append("code \(error["code"]?.string ?? "nil") != \(code)") }
        if error["message_key"]?.string != messageKey { p.append("message_key \(error["message_key"]?.string ?? "nil") != \(messageKey)") }
        if error["fields"] != nil { p.append("fields present on a non-validation error") }
        guard let id = root["request_id"]?.string else { p.append("request_id missing"); return p }
        if UUID(uuidString: id) == nil { p.append("request_id not a uuid") }
        if reply.header("X-Request-Id") != id { p.append("X-Request-Id header differs from body request_id") }
        return p
    }
}
