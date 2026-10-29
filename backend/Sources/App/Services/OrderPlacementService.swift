import Foundation
import BanhContracts

/// Places an order in the sequence of api.md 4.3 "Order of checks": the first
/// failing check is the answer, and only the last step writes (one
/// transaction in the repository, ADR-0008). Time and codes are injected.
struct OrderPlacementService: Sendable {
    /// ADR-0009: draw again on a unique-index collision, up to this many draws.
    static let maxCodeDraws = 5
    static let phoneWindowSeconds: TimeInterval = 24 * 60 * 60

    let repository: any OrderRepository
    let calendar: ShopCalendar
    let orderCodes: any OrderCodeGenerator
    let maxOrdersPerPhonePerDay: Int

    func place(_ command: OrderCommand) async throws -> OrderPlacementResult {
        let request = command.request
        let data = try await repository.loadReferenceData(
            shopID: command.shopID, productIDs: request.items.map(\.productID),
            slotID: request.slotID, districtID: request.districtID
        )
        try OrderRules.validateAgainstSettings(request, rules: data.rules)

        let hash = OrderRequestHash.make(request)
        if let stored = try await repository.findOrder(shopID: command.shopID, idempotencyKey: command.idempotencyKey) {
            return try replay(stored, hash: hash)
        }

        try OrderRules.requireUsableReferences(request, data: data)
        try OrderRules.requireAllowedOrder(request, data: data, today: calendar.today(), calendar: calendar)
        // Step 4 guarantees both exist.
        guard let slot = data.slot, let district = data.district else { throw APIError(.internalError) }
        let quote = OrderQuote.make(for: request, products: data.products, district: district)
        try quote.requireTotal(equalTo: request.expectedTotalVND)
        try await requirePhoneBelowLimit(command)

        return try await insert(command, hash: hash, data: data, slot: slot, district: district, quote: quote)
    }

    private func replay(_ stored: StoredOrder, hash: String) throws -> OrderPlacementResult {
        guard stored.requestHash == hash else { throw APIError(.idempotencyKeyReused) }
        return .replayed(stored.placed)
    }

    /// Step 7. Counts orders stored for the phone in the last 24 hours (every
    /// status: a cancelled order still cost the shop a conversation).
    private func requirePhoneBelowLimit(_ command: OrderCommand) async throws {
        let since = calendar.clock.now().addingTimeInterval(-Self.phoneWindowSeconds)
        let count = try await repository.countOrders(
            shopID: command.shopID, phone: command.request.customerPhone, since: since
        )
        if count >= maxOrdersPerPhonePerDay {
            // The true wait depends on the oldest order; the cap keeps the hint honest and bounded.
            throw APIError.rateLimited(retryAfterSeconds: APIError.maxRetryAfterSeconds)
        }
    }

    /// Step 8. A lost race is resolved by reading the winner: the same key
    /// replays (also when the winner took the last cakes), another body is a
    /// reuse error.
    private func insert(
        _ command: OrderCommand, hash: String, data: OrderReferenceData,
        slot: OrderSlotRecord, district: OrderDistrictRecord, quote: OrderQuote
    ) async throws -> OrderPlacementResult {
        for _ in 0..<Self.maxCodeDraws {
            let order = NewOrder(
                shopID: command.shopID, orderID: UUID(), orderCode: orderCodes.makeCode(),
                idempotencyKey: command.idempotencyKey, requestHash: hash, request: command.request,
                lines: quote.lines, slot: slot, district: district,
                itemsSubtotalVND: quote.itemsSubtotalVND, totalVND: quote.totalVND,
                dailyLimit: data.rules.dailyLimit, platform: command.platform, appVersion: command.appVersion,
                createdAt: calendar.clock.now()
            )
            switch try await repository.insertOrder(order) {
            case .created(let placed):
                return .created(placed)
            case .codeCollision:
                continue
            case .duplicateKey:
                return try await replayWinner(command, hash: hash)
            case .capacityExceeded:
                // A retry of an order that just succeeded must not see "full".
                if let winner = try await repository.findOrder(shopID: command.shopID, idempotencyKey: command.idempotencyKey) {
                    return try replay(winner, hash: hash)
                }
                throw APIError(.dateCapacity, details: ["delivery_date": .string(command.request.deliveryDate.description)])
            }
        }
        throw APIError(.internalError)
    }

    private func replayWinner(_ command: OrderCommand, hash: String) async throws -> OrderPlacementResult {
        guard let winner = try await repository.findOrder(shopID: command.shopID, idempotencyKey: command.idempotencyKey) else {
            throw APIError(.internalError)
        }
        return try replay(winner, hash: hash)
    }
}
