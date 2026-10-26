import Vapor

/// `GET /privacy` (api.md 4.5): the privacy statement as an HTML page, kept as
/// a file so the owner can edit the text without a code change.
struct PrivacyRoutes: RouteCollection {
    static let path: PathComponent = "privacy"
    static let fileName = "privacy.html"
    // The text may change when the owner supplies it; the file's ETag lets
    // clients revalidate cheaply instead of caching a stale statement.
    static let cacheControl = "no-cache"

    /// Directory holding `privacy.html`, ending with a slash.
    let directory: String

    func boot(routes: any RoutesBuilder) throws {
        routes.get(Self.path, use: serve)
    }

    private func serve(_ req: Request) async throws -> Response {
        try await StaticFileResponder(cacheControl: Self.cacheControl)
            .respond(to: req, withFileAt: directory + Self.fileName)
    }
}
