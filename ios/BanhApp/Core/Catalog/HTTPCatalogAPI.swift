import BanhContracts
import Foundation

nonisolated struct HTTPCatalogAPI: CatalogAPI {
    private static let path = "v1/catalog"
    private static let etagHeader = "ETag"
    private static let ifNoneMatchHeader = "If-None-Match"

    /// Reads are tried twice: the first call after idle can fail while the free host wakes (api.md section 1).
    private static let readAttempts = 2

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchCatalog(etag: String?) async throws -> CatalogFetchResult {
        let headers = etag.map { [Self.ifNoneMatchHeader: $0] } ?? [:]
        return try await retryingTransientFailures { try await fetchOnce(headers: headers) }
    }

    private func fetchOnce(headers: [String: String]) async throws -> CatalogFetchResult {
        let (data, response) = try await client.get(path: Self.path, headers: headers)
        if response.statusCode == APIClient.notModifiedStatus { return .notModified }
        guard let catalog = try? JSONDecoder().decode(CatalogResponse.self, from: data) else {
            throw APIError.invalidResponse
        }
        // Stored as received, quotes included: the server compares the exact validator it issued.
        return .modified(catalog, etag: response.value(forHTTPHeaderField: Self.etagHeader))
    }

    private func retryingTransientFailures<T>(_ operation: () async throws -> T) async throws -> T {
        for _ in 1..<Self.readAttempts {
            do {
                return try await operation()
            } catch let error as APIError where error.isTransient {
                continue
            }
        }
        return try await operation()
    }
}
