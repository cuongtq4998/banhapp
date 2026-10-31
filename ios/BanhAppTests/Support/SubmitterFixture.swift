import BanhContracts
import XCTest
@testable import BanhApp

/// A review ready to send: the flow, its store, a scripted API and the orders passed on.
@MainActor
enum SubmitterFixture {
    struct Setup {
        let submitter: OrderSubmitter
        let flow: OrderFlow
        let store: InMemoryDraftStore
        let api: ScriptedOrderAPI
        let placed: Placed
    }

    final class Placed {
        var orders: [PlacedOrder] = []
    }

    /// 2 x Bánh chuối (35.000) + 1 x Bánh đậu xanh nhân mỡ (45.000) + fee 20.000 = 135.000.
    static func make(_ replies: [ScriptedOrderAPI.Reply], delay: Duration? = nil) async throws -> Setup {
        var draft = OrderDraft(savedAt: OrderTestSupport.now)
        let ok = try CatalogTestData.okCatalog()
        draft.setQuantity(2, of: ok.products[0].productID, name: ok.products[0].name)
        draft.setQuantity(1, of: ok.products[1].productID, name: ok.products[1].name)
        draft.date = ShopDate(year: 2026, month: 11, day: 4)
        draft.slotID = OrderTestSupport.id(33)
        draft.name = " Nguyễn Văn An "
        draft.phone = "0912 345 678"
        draft.address = "12 Đường Số 3"
        draft.districtID = OrderTestSupport.id(23)
        let store = InMemoryDraftStore(draft: draft)
        let flow = try await OrderTestSupport.flow(draft: draft, store: store)
        let api = ScriptedOrderAPI(replies, delay: delay)
        let placed = Placed()
        let submitter = OrderSubmitter(flow: flow, api: api) { placed.orders.append($0) }
        return Setup(submitter: submitter, flow: flow, store: store, api: api, placed: placed)
    }
}
