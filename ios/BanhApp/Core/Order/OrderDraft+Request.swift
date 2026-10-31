import BanhContracts

extension OrderDraft {
    /// The body of `POST /v1/orders` (api.md 4.3). Texts go out trimmed and in NFC, the same form the
    /// server counts and stores (ADR-0009); an empty note is an explicit `null`. Nil while something the
    /// body needs is missing, which the review's blockers prevent.
    func orderRequest() -> OrderRequestBody? {
        guard let date, let slotID, let districtID, let expectedTotalVND else { return nil }
        let cakes = items.filter { $0.quantity > 0 }
        guard !cakes.isEmpty else { return nil }
        let note = OrderValidation.canonical(self.note)
        return OrderRequestBody(
            items: cakes.map { OrderItemRequest(productID: $0.productID, quantity: $0.quantity) },
            deliveryDate: date.iso,
            slotID: slotID,
            customer: OrderCustomerRequest(
                name: OrderValidation.canonical(name),
                phone: OrderValidation.canonical(phone),
                address: OrderValidation.canonical(address),
                districtID: districtID
            ),
            note: note.isEmpty ? nil : note,
            expectedTotalVND: expectedTotalVND
        )
    }
}
