import BanhCore
import Foundation
import Testing
@testable import BanhAdmin

/// The fake shop of the UI tests must answer in a shape the app decodes, for every order.
struct StubOrderDecodeTests {
    @Test(arguments: StubOrderData.orders.map(\.orderCode))
    func everyStubOrderRoundTripsThroughTheWireFormat(code: String) throws {
        let order = try #require(StubOrderData.orders.first { $0.orderCode == code })
        let data = try APIClient.encoder.encode(order)
        let decoded = try APIClient.decoder.decode(OrderDetail.self, from: data)
        #expect(decoded.orderCode == code)
    }
}
