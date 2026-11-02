import XCTVapor
@testable import App

/// Planted orders and requests behind each lookup fixture.
extension LookupRouteTestCase {
    private func row(_ n: Int, _ status: String, final: Int?, expected: String? = nil, items: Int = 2) -> LookupRow {
        let base = LookupRow.sample(n)
        return LookupRow(
            id: base.id, order_code: "BT-FIX00\(n)", status: status, created_at: base.created_at,
            district_name: base.district_name, requested: base.requested, slot_start: base.slot_start,
            slot_end: base.slot_end, expected: expected, items_subtotal_vnd: 150_000, delivery_fee_vnd: 20_000,
            delivery_fee_final_vnd: final,
            items: [.init(cakeName: "Banh Mau", quantity: 1, unitPriceVnd: 50_000),
                    .init(cakeName: "Banh Tra", quantity: 2, unitPriceVnd: 50_000)].prefix(items).map { $0 }
        )
    }

    private func post(_ json: String) async throws -> (Int, Data) {
        var result = (0, Data())
        try await lookup(json) { res in result = (Int(res.status.code), Data(res.body.readableBytesView)) }
        return result
    }

    /// Answer of one named scenario (status and body), from the real route.
    func scenario(_ name: String) async throws -> (Int, Data) {
        let request = #"{"phone":"\#(phone)"}"#
        var tuned = LookupPolicy()
        tuned.floorMilliseconds = 0
        switch name {
        case "answer-open":
            try await start()
            store.plant(normalised, [row(1, "Received", final: nil), row(2, "Processing", final: nil),
                                     row(3, "DeliveryDateScheduled", final: nil, expected: "2026-11-06"),
                                     row(4, "DeliveryStarted", final: 25_000, expected: "2026-11-06")])
        case "answer-fee-zero":
            try await start()
            store.plant(normalised, [row(1, "Finished", final: 0, expected: "2026-11-05")])
        case "answer-fee-corrected":
            try await start()
            store.plant(normalised, [row(1, "DeliveryStarted", final: 35_000, expected: "2026-11-06")])
        case "answer-cancelled":
            try await start()
            store.plant(normalised, [row(1, "Cancelled", final: nil)])
        case "answer-empty":
            try await start()
            store.plant(normalised, [])
        case "answer-page-one", "answer-last-page":
            try await start()
            store.plant(normalised, (1...12).map { row($0, "Received", final: nil, items: 1) })
            guard name == "answer-last-page" else { break }
            let first = try JSONSerialization.jsonObject(with: try await post(request).1) as? [String: Any]
            let cursor = first?["next_cursor"] as? String ?? ""
            return try await post(#"{"phone":"\#(phone)","cursor":"\#(cursor)"}"#)
        case "error-lookup-phone-required":
            try await start()
            return try await post("{}")
        case "error-lookup-phone-invalid":
            try await start()
            return try await post(#"{"phone":"12345"}"#)
        case "error-lookup-cursor-invalid":
            try await start()
            return try await post(#"{"phone":"\#(phone)","cursor":"not-a-cursor"}"#)
        case "error-lookup-rate-limited":
            tuned.perPhonePerHour = 1
            try await start(policy: tuned)
            _ = try await post(request)
            return try await post(request)
        default: XCTFail("unknown scenario \(name)")
        }
        return try await post(request)
    }
}
