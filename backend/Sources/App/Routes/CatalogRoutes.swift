import Vapor
import BanhContracts

/// `GET /v1/catalog` (api.md 4.1). Parses the request, asks `CatalogService`,
/// encodes the answer with its `ETag`.
struct CatalogRoutes: RouteCollection {
    static let cacheControl = "no-cache"

    /// Nil only in a local run without `SHOP_ID`; the endpoint then reports
    /// itself unavailable instead of guessing a shop.
    let shopID: UUID?
    let assets: AssetURLBuilder

    func boot(routes: any RoutesBuilder) throws {
        routes.get("v1", "catalog", use: catalog)
    }

    private func catalog(_ req: Request) async throws -> Response {
        guard let shopID, let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }
        let services = req.application.services
        let service = CatalogService(
            repository: services.repositories.makeCatalogRepository(database),
            calendar: services.calendar,
            assets: assets,
            logger: req.logger
        )
        let body = try Self.makeEncoder().encode(try await service.makeCatalog(shopID: shopID))
        let tag = EntityTag(hashing: body)

        // A 304 must repeat the validators and carry no body (RFC 9110 15.4.5).
        // Repeated If-None-Match lines combine into one comma-separated list (RFC 9110 5.3).
        let ifNoneMatch = req.headers[.ifNoneMatch]
        let notModified = tag.isListed(inIfNoneMatch: ifNoneMatch.isEmpty ? nil : ifNoneMatch.joined(separator: ","))
        let response = Response(status: notModified ? .notModified : .ok)
        response.headers.replaceOrAdd(name: .eTag, value: tag.headerValue)
        response.headers.replaceOrAdd(name: .cacheControl, value: Self.cacheControl)
        if !notModified {
            response.headers.contentType = .json
            response.body = .init(data: body)
        }
        return response
    }

    // Sorted keys make the bytes, and so the ETag, independent of dictionary
    // ordering; unescaped slashes keep `image_url` readable.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
