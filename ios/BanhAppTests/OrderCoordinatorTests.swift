import BanhContracts
import XCTest
@testable import BanhApp

/// Navigation of the flow: where each entry starts and that going back keeps the stack consistent.
@MainActor
final class OrderCoordinatorTests: XCTestCase {
    private func make(store: InMemoryDraftStore = InMemoryDraftStore()) async throws -> (OrderCoordinator, InMemoryDraftStore, AppEnvironment) {
        let environment = AppEnvironment(
            catalogRepository: await OrderTestSupport.repository(try CatalogTestData.okCatalog()),
            availabilityAPI: try StubAvailability.fixture(),
            orderAPI: ScriptedOrderAPI([]),
            draftStore: store,
            urlOpener: StubOpener(),
            assetBaseURL: URL(string: "http://localhost:9")!
        )
        return (OrderCoordinator(environment: environment, now: { OrderTestSupport.now }), store, environment)
    }

    private struct StubOpener: URLOpener {
        func open(_ url: URL) async -> Bool { true }
    }

    func testStartingFromACakeBeginsANewDraftWithThatCakeAtOne() async throws {
        var old = OrderDraft(savedAt: OrderTestSupport.now)
        old.name = "Someone earlier"
        let (coordinator, store, _) = try await make(store: InMemoryDraftStore(draft: old))
        let cake = try CatalogTestData.okCatalog().products[2]

        XCTAssertEqual(coordinator.start(startingWith: cake.productID), .orderStep(.cakes))

        let saved = try XCTUnwrap(store.load(now: OrderTestSupport.now))
        XCTAssertEqual(saved.quantity(of: cake.productID), 1)
        XCTAssertEqual(saved.totalQuantity, 1)
        XCTAssertEqual(saved.name, "")
    }

    func testStartingFromTheHomeRestoresTheSavedDraftWithoutAPrompt() async throws {
        var old = OrderDraft(savedAt: OrderTestSupport.now)
        old.name = "An"
        old.setQuantity(3, of: OrderTestSupport.id(11), name: "Bánh chuối")
        let (coordinator, store, _) = try await make(store: InMemoryDraftStore(draft: old))

        XCTAssertEqual(coordinator.start(), .orderStep(.cakes))
        XCTAssertEqual(store.load(now: OrderTestSupport.now)?.name, "An")
    }

    func testStartingWithNoDraftBeginsEmpty() async throws {
        let (coordinator, store, _) = try await make()
        _ = coordinator.start()
        XCTAssertNil(store.load(now: OrderTestSupport.now))
    }

    func testAdvanceWalksS5ToS8AndStopsAtTheEnd() async throws {
        let (coordinator, _, _) = try await make()
        var path: [Route] = [.orderStep(.cakes)]
        for step in [OrderStep.cakes, .date, .recipient] { coordinator.advance(from: step, path: &path) }
        XCTAssertEqual(path, OrderStep.allCases.map { .orderStep($0) })
        coordinator.advance(from: .review, path: &path)
        XCTAssertEqual(path.count, 4)
    }

    func testEditGoesBackToTheStepOnTheStack() async throws {
        let (coordinator, _, _) = try await make()
        var path: [Route] = [.products] + OrderStep.allCases.map { .orderStep($0) }
        coordinator.edit(.date, path: &path)
        XCTAssertEqual(path, [.products, .orderStep(.cakes), .orderStep(.date)])
        coordinator.edit(.cakes, path: &path)
        XCTAssertEqual(path, [.products, .orderStep(.cakes)])
    }

    func testStepsAreNumberedOneToFour() {
        XCTAssertEqual(OrderStep.allCases.map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(OrderStep.count, 4)
    }
}
