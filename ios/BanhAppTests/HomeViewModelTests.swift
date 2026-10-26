import BanhContracts
import XCTest
@testable import BanhApp

@MainActor
final class HomeViewModelTests: XCTestCase {
    private final class RecordingOpener: URLOpener {
        var opened: [URL] = []
        var canOpen = true

        func open(_ url: URL) async -> Bool {
            opened.append(url)
            return canOpen
        }
    }

    private func makeModel(opener: RecordingOpener, loaded: Bool = true) async throws -> HomeViewModel {
        let api = StubCatalogAPI([loaded ? .success(.modified(try CatalogTestData.okCatalog(), etag: nil)) : .failure(.networkUnavailable)])
        let repository = CatalogRepository(api: api, cache: InMemoryCatalogCache())
        let model = HomeViewModel(repository: repository, contact: ContactActions(opener: opener))
        await model.retry()
        return model
    }

    func testShopInformationEnablesTheActions() async throws {
        let model = try await makeModel(opener: RecordingOpener())
        guard case .ready(let shop) = model.state else { return XCTFail("Expected the shop") }
        XCTAssertEqual(shop.name, "Tiệm Bánh An Nhiên")
        XCTAssertTrue(model.actionsEnabled)
    }

    func testActionsAreDisabledBeforeTheShopIsKnownAndAfterAFailedLoad() async throws {
        let failed = try await makeModel(opener: RecordingOpener(), loaded: false)
        XCTAssertFalse(failed.actionsEnabled)
        XCTAssertEqual(failed.state, .failed(.network))

        let repository = CatalogRepository(api: StubCatalogAPI([.failure(.networkUnavailable)]), cache: InMemoryCatalogCache())
        let loading = HomeViewModel(repository: repository, contact: ContactActions(opener: RecordingOpener()))
        XCTAssertTrue(loading.state.isLoading)
        XCTAssertFalse(loading.actionsEnabled)
    }

    func testZaloOpensTheWebLinkOfTheShopContact() async throws {
        let opener = RecordingOpener()
        let model = try await makeModel(opener: opener)
        await model.openZalo()
        XCTAssertEqual(opener.opened.map(\.absoluteString), ["https://zalo.me/84900000000"])
        XCTAssertNil(model.contact.failure)
    }

    func testPhoneOpensTheDialerWithTheShopNumber() async throws {
        let opener = RecordingOpener()
        let model = try await makeModel(opener: opener)
        await model.openPhone()
        XCTAssertEqual(opener.opened.map(\.absoluteString), ["tel:+84900000000"])
    }

    func testALinkTheSystemCannotOpenSetsTheMatchingToast() async throws {
        let opener = RecordingOpener()
        opener.canOpen = false
        let model = try await makeModel(opener: opener)

        await model.openZalo()
        XCTAssertEqual(model.contact.failure, .zalo)
        XCTAssertEqual(String(localized: ContactActions.Failure.zalo.message), String(localized: Strings.errorOpenZalo))

        await model.openPhone()
        XCTAssertEqual(model.contact.failure, .phone)
    }

    func testASuccessfulOpenClearsAnEarlierFailure() async throws {
        let opener = RecordingOpener()
        opener.canOpen = false
        let model = try await makeModel(opener: opener)
        await model.openPhone()
        opener.canOpen = true
        await model.openPhone()
        XCTAssertNil(model.contact.failure)
    }

    func testNothingOpensWhileTheShopIsUnknown() async throws {
        let opener = RecordingOpener()
        let model = try await makeModel(opener: opener, loaded: false)
        await model.openZalo()
        await model.openPhone()
        XCTAssertTrue(opener.opened.isEmpty)
    }
}
