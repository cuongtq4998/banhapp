import BanhContracts
import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

/// The six status words, the legacy history words, the fixtures and the sheet rules (api/09 10.13).
struct OrderProcessModelTests {
    private static let fixtureDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "contracts/fixtures/admin")

    private func body(_ name: String) throws -> Data {
        let url = Self.fixtureDir.appending(path: "\(name).json")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try JSONSerialization.data(withJSONObject: root["body"] ?? root)
    }

    @Test func unknownAndLegacyStatusWords() throws {
        #expect(OrderStatus(word: "DeliveryStarted") == .deliveryStarted)
        #expect(OrderStatus(word: "Shipped") == .unknown("Shipped"))
        #expect(OrderStatus(word: "New") == .unknown("New"))
        #expect([OrderStatus(historyWord: "New"), .init(historyWord: "Confirmed"), .init(historyWord: "Completed")]
            == [.received, .processing, .finished])
        let decoded = try JSONDecoder().decode([OrderStatus].self, from: Data(#"["Zzz","Finished"]"#.utf8))
        #expect(decoded == [.unknown("Zzz"), .finished])
    }

    @Test func everyOrderFixtureDecodes() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: Self.fixtureDir.path)
            .filter { $0.hasPrefix("order-detail") || $0 == "order-status-change.json" }
        #expect(names.count >= 7)
        for name in names {
            let detail = try APIClient.decoder.decode(OrderDetail.self, from: body(String(name.dropLast(5))))
            #expect(!detail.orderCode.isEmpty, "\(name)")
            #expect(!detail.allowedActions.contains(.unknown), "\(name)")
        }
        let page = try APIClient.decoder.decode(OrderPage.self, from: body("orders-list"))
        #expect(page.items.allSatisfy { !$0.listDate.isEmpty })
    }

    @Test func feeFixtureFieldsAndMissingNulls() throws {
        let fee = try APIClient.decoder.decode(OrderDetail.self, from: body("order-detail-fee-corrected"))
        #expect(fee.deliveryFeeFinalVnd == 35_000 && fee.amountToCollectVnd == 135_000)
        #expect(fee.feeCorrections.count == 2 && fee.lastChange.kind == "fee")
        #expect(fee.expectedDateRange == DateRange(min: "2026-11-02", max: "2026-11-09"))
        let json = #"{"order_code":"X","status":"Received","customer_name":"A","delivery_date":"2026-11-02","slot":{"start":"08:00","end":"10:00"},"total_cakes":1,"total_vnd":1,"district_name":"D","created_at":"t","customer_phone":"p","customer_address":"a","items":[],"items_subtotal_vnd":1,"delivery_fee_vnd":0,"allowed_actions":["cancel","teleport"],"date_changes":[],"fee_corrections":[],"last_change":{"at":"t"}}"#
        let sparse = try APIClient.decoder.decode(OrderDetail.self, from: Data(json.utf8))
        #expect(sparse.amountToCollectVnd == nil && sparse.deliveryFeeFinalVnd == nil)
        #expect(sparse.actions == [.cancel] && !sparse.allows(.process))
    }

    @Test func dateEntryUsesTheServerRange() {
        let range = DateRange(min: "2026-11-02", max: "2026-11-09")
        var entry = DateEntry(range: range, current: "2026-11-04")
        #expect(!entry.canSave)
        entry.chosen = "2026-11-10"
        #expect(!entry.canSave)
        entry.chosen = "2026-11-09"
        #expect(entry.canSave)
        #expect(!DateEntry(range: nil, current: nil).canSave)
    }

    @Test func feeEntryRules() {
        var entry = FeeEntryState(previous: nil, cakesSubtotalVnd: 100_000)
        #expect(!entry.canSave && entry.preview == nil)
        for (text, ok) in [("0", true), ("10000000", true), ("10000001", false), ("-5", false), ("1.5", false), ("abc", false)] {
            entry.text = text
            #expect(entry.isValid == ok, "\(text)")
        }
        entry.text = "20000"
        #expect(entry.preview == 120_000)
        #expect(!FeeEntryState(previous: 20_000, cakesSubtotalVnd: 1, text: "20000").canSave)
    }

    @Test func tooFarErrorKeepsTheRange() throws {
        let response = HTTPURLResponse(url: URL(string: "http://x")!, statusCode: 422, httpVersion: nil, headerFields: nil)!
        let url = Self.fixtureDir.appending(path: "error-validation-expected-date-too-far.json")
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let error = APIErrorParser.parse(try JSONSerialization.data(withJSONObject: root["body"] ?? root), response: response)
        #expect(EntryError(error) == .dateTooFar(DateRange(min: "2026-11-02", max: "2026-11-09")))
    }
}

@MainActor
struct OrderProcessViewModelTests {
    @Test func buttonsComeOnlyFromAllowedActions() async {
        let api = FakeOrdersAPI()
        api.detail = .success(TestData.detail(status: .received, actions: [.changeDate]))
        let model = OrderDetailViewModel(code: "BT-7K3M9Q", api: api, onChanged: {})
        await model.load()
        model.openStartDeliverySheet()
        #expect(model.feeEntry == nil)
        model.openChangeDateSheet()
        #expect(model.dateEntry?.current == "2026-11-04")
        await model.process()
        #expect(api.statusCalls.count == 1)
    }

    @Test func startDeliverySendsTheFee() async {
        let api = FakeOrdersAPI()
        api.detail = .success(TestData.detail(status: .deliveryDateScheduled, actions: [.startDelivery]))
        let model = OrderDetailViewModel(code: "BT-7K3M9Q", api: api, onChanged: {})
        await model.load()
        model.openStartDeliverySheet()
        model.feeEntry?.text = "0"
        await model.startDelivery()
        #expect(api.statusCalls.first?.deliveryFeeVnd == 0)
        #expect(api.statusCalls.first?.target == .deliveryStarted)
    }

    @Test func changeDateSendsPreviousAndNew() async {
        let api = FakeOrdersAPI()
        api.detail = .success(TestData.detail(status: .deliveryDateScheduled, actions: [.changeDate]))
        let model = OrderDetailViewModel(code: "BT-7K3M9Q", api: api, onChanged: {})
        await model.load()
        model.openChangeDateSheet()
        await model.changeDate()
        #expect(api.dateCalls.isEmpty)
        model.dateEntry?.chosen = "2026-11-06"
        await model.changeDate()
        #expect(api.dateCalls.first?.previous == "2026-11-04" && api.dateCalls.first?.date == "2026-11-06")
    }

    @Test func feeErrorStaysInTheSheet() async {
        let api = FakeOrdersAPI()
        api.detail = .success(TestData.detail(status: .deliveryDateScheduled, actions: [.startDelivery]))
        api.outcome = .failure(APIError.service(code: "VALIDATION_FAILED", messageKey: "ERR_SERVER", httpStatus: 422, details: [
            "_fields": .array([.object(["field": .string("delivery_fee_vnd"), "code": .string("FEE_INVALID")])])]))
        let model = OrderDetailViewModel(code: "BT-7K3M9Q", api: api, onChanged: {})
        await model.load()
        model.openStartDeliverySheet()
        model.feeEntry?.text = "5"
        await model.startDelivery()
        #expect(model.entryError == .feeInvalid && model.feeEntry != nil)
    }
}
