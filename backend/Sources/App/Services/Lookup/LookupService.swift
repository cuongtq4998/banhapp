import Foundation

/// Decides one lookup page: window, paging, cursor, masking (api/10).
struct LookupService: Sendable {
    let store: any LookupStore
    let policy: LookupPolicy
    let hasher: LookupKeyHasher
    let clock: any WallClock

    /// Nil cursor text starts at the first page; a bad cursor throws `CURSOR_INVALID`.
    func page(phone: String, cursorText: String?) async throws -> LookupAnswer {
        let cursor = try cursorText.map { try decodeCursor($0, phone: phone) }
        let now = clock.now()
        // One extra row tells whether another page exists.
        let rows = try await store.fetchPage(
            phone: phone, cursor: cursor, windowStart: now.addingTimeInterval(-policy.retention), limit: policy.pageSize + 1
        )
        let pageRows = Array(rows.prefix(policy.pageSize))
        let pageNumber = cursor?.page ?? 1
        let hasMore = rows.count > policy.pageSize && pageNumber < policy.maxPages
        let next = hasMore ? pageRows.last.map {
            LookupCursor(placedAt: $0.created_at, orderID: $0.id, page: pageNumber + 1).encode(phone: phone, hasher: hasher)
        } : nil
        return LookupAnswer(orders: pageRows.map { view($0, phone: phone) }, nextCursor: next, asOf: now)
    }

    private func decodeCursor(_ text: String, phone: String) throws -> LookupCursor {
        guard let cursor = LookupCursor.decode(text, phone: phone, hasher: hasher) else { throw LookupError.cursorInvalid }
        return cursor
    }

    private func view(_ row: LookupRow, phone: String) -> LookupOrderView {
        LookupOrderView(
            orderCode: row.order_code, status: row.status, placedAt: row.created_at,
            phoneMasked: LookupOrderView.mask(phone: phone), districtName: row.district_name,
            requestedDeliveryDate: row.requested, slotStartTime: row.slot_start, slotEndTime: row.slot_end,
            expectedDeliveryDate: row.expected, items: row.items, itemsSubtotalVnd: row.items_subtotal_vnd,
            deliveryFeeEstimateVnd: row.delivery_fee_vnd, deliveryFeeFinalVnd: row.delivery_fee_final_vnd,
            amountToCollectVnd: row.delivery_fee_final_vnd.map { row.items_subtotal_vnd + $0 }
        )
    }
}

enum LookupError: Error { case cursorInvalid }
