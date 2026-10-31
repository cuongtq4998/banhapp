import BanhContracts
import XCTest
@testable import BanhApp

final class HTTPAvailabilityAPITests: XCTestCase {
    private func makeAPI(_ replies: [StubHTTPTransport.Reply]) -> (HTTPAvailabilityAPI, StubHTTPTransport) {
        let transport = StubHTTPTransport(replies)
        let client = APIClient(baseURL: URL(string: "http://localhost:8080")!, appVersion: "9.9", transport: transport)
        return (HTTPAvailabilityAPI(client: client), transport)
    }

    func testRequestsTheOrderSizeAndDecodesTheFixture() async throws {
        let body = try Fixtures.data("availability-ok.json")
        let (api, transport) = makeAPI([.response(status: 200, body: body)])

        let response = try await api.fetchAvailability(cakes: 3)

        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "http://localhost:8080/v1/availability?cakes=3")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "X-Platform"), "ios")
        XCTAssertNil(transport.requests.first?.value(forHTTPHeaderField: "If-None-Match"))
        XCTAssertEqual(response, try Fixtures.decode(AvailabilityResponse.self, from: "availability-ok.json"))
        XCTAssertEqual(response.dates.count, 31)
    }

    func testFixtureDrivesTheDayStates() throws {
        let days = try XCTUnwrap(DayAvailability(response: Fixtures.decode(AvailabilityResponse.self, from: "availability-ok.json")))
        XCTAssertEqual(days.state(of: ShopDate(year: 2026, month: 11, day: 3)), .tooSoon)
        XCTAssertEqual(days.state(of: ShopDate(year: 2026, month: 11, day: 4)), .available)
        XCTAssertEqual(days.state(of: ShopDate(year: 2026, month: 11, day: 5)), .full)
        XCTAssertEqual(days.state(of: ShopDate(year: 2026, month: 12, day: 2)), .available)
        XCTAssertEqual(days.state(of: ShopDate(year: 2026, month: 12, day: 3)), .tooFar)
        XCTAssertEqual(days.state(of: ShopDate(year: 2026, month: 10, day: 30)), .tooSoon)
    }

    func testAnErrorEnvelopeIsThrownAsAnAPIError() async throws {
        let body = try Fixtures.data("error-service-unavailable.json")
        let (api, _) = makeAPI([.response(status: 503, body: body)])
        do {
            _ = try await api.fetchAvailability(cakes: 2)
            XCTFail("Expected an error")
        } catch let error as APIError {
            guard case .service(let code, _, let status, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(status, 503)
            XCTAssertEqual(code, .serviceUnavailable)
        }
    }

    func testABodyThatIsNotTheContractIsInvalid() async throws {
        let (api, _) = makeAPI([.response(status: 200, body: Data("{}".utf8))])
        do {
            _ = try await api.fetchAvailability(cakes: 2)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? APIError, .invalidResponse)
        }
    }

    func testOfflineIsReportedAsNetworkUnavailable() async throws {
        let (api, _) = makeAPI([.failure(.networkUnavailable)])
        do {
            _ = try await api.fetchAvailability(cakes: 2)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? APIError, .networkUnavailable)
        }
    }
}
