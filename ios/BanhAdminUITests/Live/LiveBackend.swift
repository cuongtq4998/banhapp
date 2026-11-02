import Foundation

/// Plain URLSession calls to the real backend, used where the UI cannot be driven (the photo picker,
/// the owner's second sign-in) and to check what the backend answers. Synchronous on purpose.
struct LiveResponse {
    let status: Int
    let body: Data
    var json: [String: Any] { (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:] }
    var text: String { String(decoding: body, as: UTF8.self) }
}

enum LiveBackend {
    static func send(_ method: String, _ path: String, token: String? = nil, json: Any? = nil,
                     headers: [String: String] = [:], body: Data? = nil) -> LiveResponse {
        var request = URLRequest(url: URL(string: Live.baseURL.absoluteString + path)!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        request.setValue("1.0.0", forHTTPHeaderField: "X-App-Version")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let json {
            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let body { request.httpBody = body }
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let done = DispatchSemaphore(value: 0)
        var result = LiveResponse(status: -1, body: Data())
        URLSession.shared.dataTask(with: request) { data, response, _ in
            result = LiveResponse(status: (response as? HTTPURLResponse)?.statusCode ?? -1, body: data ?? Data())
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 30)
        return result
    }

    /// The first date the customer can pick for `cakes` cakes, and the ids the order form needs.
    static func firstAvailableDate(cakes: Int = 2, skip: Int = 0) -> String {
        let dates = send("GET", "/v1/availability?cakes=\(cakes)").json["dates"] as? [[String: Any]] ?? []
        let open = dates.filter { $0["available"] as? Bool == true }.compactMap { $0["date"] as? String }
        return open.indices.contains(skip) ? open[skip] : ""
    }

    static func catalog() -> [String: Any] { send("GET", "/v1/catalog").json }

    static func productNames() -> [String] {
        (catalog()["products"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
    }

    /// `POST /v1/orders` for the fake phone: 2 cakes of the first product, the first slot and district.
    static func placeOrder(phone: String, date: String, name: String = "Direct Api") -> LiveResponse {
        let catalog = catalog()
        let product = (catalog["products"] as? [[String: Any]])?.first
        let price = product?["price_vnd"] as? Int ?? 0
        let district = (catalog["districts"] as? [[String: Any]])?.first
        let fee = district?["delivery_fee_vnd"] as? Int ?? 0
        let body: [String: Any] = [
            "items": [["product_id": product?["product_id"] ?? "", "quantity": 2]],
            "delivery_date": date,
            "slot_id": (catalog["slots"] as? [[String: Any]])?.first?["slot_id"] ?? "",
            "customer": ["name": name, "phone": phone, "address": "9 Duong Test", "district_id": district?["district_id"] ?? ""],
            "note": NSNull(),
            "expected_total_vnd": price * 2 + fee,
        ]
        return send("POST", "/v1/orders", json: body, headers: ["Idempotency-Key": UUID().uuidString])
    }
}
