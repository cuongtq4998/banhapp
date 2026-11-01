import Vapor
import Fluent
import FluentSQL

/// `GET /assets/cakes/{product_id}`: the picture of an uploaded cake, read
/// from the database (ADR-0025). The URL carries the content hash (`?v=`), so
/// the answer can be cached for a year. A removed or unknown cake, or one
/// without a stored picture, is 404.
struct CakeImageRoutes: RouteCollection {
    static let cacheControl = "public, max-age=31536000, immutable"

    /// Nil only in a local run without `SHOP_ID`; the route then answers 503.
    let shopID: UUID?

    func boot(routes: any RoutesBuilder) throws {
        routes.get(PathComponent(stringLiteral: AssetURLBuilder.routeSegment), PathComponent(stringLiteral: AssetURLBuilder.uploadedSegment), ":id", use: serve)
    }

    private func serve(_ req: Request) async throws -> Response {
        guard let shopID, let database = req.databaseHandle else { throw APIError(.serviceUnavailable) }
        guard let id = req.parameters.get("id").flatMap(UUID.init(uuidString:)) else { throw APIError(.notFound) }
        guard let sql = database as? any SQLDatabase else { throw APIError(.internalError) }
        let row = try await translatingDatabaseErrors {
            try await sql.raw("""
                SELECT i.content_type, i.bytes FROM product_image i JOIN product p ON p.id = i.product_id
                WHERE p.id = \(bind: id) AND p.shop_id = \(bind: shopID) AND p.removed_at IS NULL
                """).first()
        }
        guard let row else { throw APIError(.notFound) }
        let response = Response(status: .ok, body: .init(data: try row.decode(column: "bytes", as: Data.self)))
        response.headers.replaceOrAdd(name: .contentType, value: try row.decode(column: "content_type", as: String.self))
        response.headers.replaceOrAdd(name: "X-Content-Type-Options", value: "nosniff")
        response.headers.replaceOrAdd(name: .cacheControl, value: Self.cacheControl)
        return response
    }
}
