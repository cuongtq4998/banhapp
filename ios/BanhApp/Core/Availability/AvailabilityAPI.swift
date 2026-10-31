import BanhContracts
import Foundation

/// Edge to `GET /v1/availability` (api.md 4.2); the date step and the tests depend on this protocol.
nonisolated protocol AvailabilityAPI: Sendable {
    /// Which dates can hold an order of `cakes` cakes. Throws `APIError` on every failure.
    func fetchAvailability(cakes: Int) async throws -> AvailabilityResponse
}

nonisolated struct HTTPAvailabilityAPI: AvailabilityAPI {
    private static let path = "v1/availability"
    private static let cakesParameter = "cakes"

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchAvailability(cakes: Int) async throws -> AvailabilityResponse {
        // Never cached or revalidated: the answer is only valid for the moment it was given (ADR-0011).
        let query = [URLQueryItem(name: Self.cakesParameter, value: String(cakes))]
        let (data, _) = try await client.get(path: Self.path, query: query)
        guard let response = try? JSONDecoder().decode(AvailabilityResponse.self, from: data) else {
            throw APIError.invalidResponse
        }
        return response
    }
}
