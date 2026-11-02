import BanhCore
import Foundation
@testable import BanhAdmin

/// Orders API fake: scripted pages and status outcomes, with the queries it saw.
final class FakeOrdersAPI: OrdersAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [OrderQuery] = []
    var pages: [OrderPage] = []
    var detail: Result<OrderDetail, Error> = .success(TestData.detail())
    var outcome: Result<StatusChangeOutcome, Error> = .success(.changed(TestData.detail(status: .confirmed)))
    var statusCalls: [(expected: OrderStatus, target: OrderStatus, reason: CancelReason?)] = []

    var queries: [OrderQuery] { lock.withLock { seen } }

    func orders(_ query: OrderQuery) async throws -> OrderPage {
        lock.withLock { seen.append(query) }
        let index = min(queries.count - 1, pages.count - 1)
        guard index >= 0 else { throw APIError.networkUnavailable }
        return pages[index]
    }

    func order(code: String) async throws -> OrderDetail { try detail.get() }

    func changeStatus(code: String, expected: OrderStatus, to target: OrderStatus, reason: CancelReason?) async throws -> StatusChangeOutcome {
        statusCalls.append((expected, target, reason))
        return try outcome.get()
    }
}

struct FakeAuth: AuthService {
    var codeResult: Result<CodeRequestResponse, Error> = .success(CodeRequestResponse(resendAfterSeconds: 30, expiresInSeconds: 600))
    var signInResult: Result<SignedInUser, Error> = .success(SignedInUser(account: AdminAccount(name: "A", role: .staff), email: "a@example.com", serverDate: "2026-11-02"))

    func requestCode(email: String) async throws -> CodeRequestResponse { try codeResult.get() }
    func signIn(email: String, code: String) async throws -> SignedInUser { try signInResult.get() }
}

enum TestData {
    static func summary(_ code: String, status: OrderStatus = .new, date: String = "2026-11-02") -> OrderSummary {
        OrderSummary(
            orderCode: code, status: status, customerName: "Tran Thi B", deliveryDate: date,
            slot: DeliverySlot(start: "08:00", end: "10:00"), totalCakes: 2, totalVnd: 120_000,
            districtName: "Quan An Phu", createdAt: "2026-10-31T03:15:09Z"
        )
    }

    static func page(_ codes: [String], next: String? = nil, unfinished: Int = 1) -> OrderPage {
        OrderPage(items: codes.map { summary($0) }, nextCursor: next, unfinishedCount: unfinished, serverDate: "2026-11-02")
    }

    static func detail(status: OrderStatus = .new) -> OrderDetail {
        OrderDetail(
            orderCode: "BT-7K3M9Q", status: status, customerName: "Tran Thi B", deliveryDate: "2026-11-02",
            slot: DeliverySlot(start: "08:00", end: "10:00"), totalCakes: 2, totalVnd: 120_000, districtName: "Quan An Phu",
            createdAt: "2026-10-31T03:15:09Z", customerPhone: "+84900000010", customerAddress: "1 Test Street", note: nil,
            items: [], itemsSubtotalVnd: 100_000, deliveryFeeVnd: 20_000, cancelReason: nil, allowedActions: [],
            lastChange: LastChange(actorName: nil, at: "2026-10-31T03:15:09Z")
        )
    }
}
