import Vapor

/// `GET /assets/images/*` (api.md 4.6): product images. The query string (the
/// `?v=` version) is ignored.
///
/// Only the `images` folder is served, so the privacy page that lives in the
/// assets directory is reachable only at its own route. A request path is
/// never joined to the directory unchecked: every segment must be a plain
/// file name.
struct AssetRoutes: RouteCollection {
    // The URL carries the file's content hash, so a changed picture is a new URL.
    static let cacheControl = "public, max-age=31536000, immutable"
    static let servedExtensions: Set<String> = ["png", "jpg", "jpeg", "webp"]

    /// The assets directory, ending with a slash; `images/` is appended.
    let directory: String

    func boot(routes: any RoutesBuilder) throws {
        routes.get(
            PathComponent(stringLiteral: AssetURLBuilder.routeSegment),
            PathComponent(stringLiteral: AssetVersions.imagesDirectoryName),
            "**",
            use: serve
        )
    }

    private func serve(_ req: Request) async throws -> Response {
        let segments = req.parameters.getCatchall()
        let imagesDirectory = directory + AssetVersions.imagesDirectoryName + "/"
        guard let path = Self.filePath(forSegments: segments, in: imagesDirectory) else {
            throw APIError(.notFound)
        }
        return try await StaticFileResponder(cacheControl: Self.cacheControl).respond(to: req, withFileAt: path)
    }

    /// The file path for a request, or nil when it could leave the directory
    /// or name something that is not an image.
    static func filePath(forSegments segments: [String], in directory: String) -> String? {
        guard !segments.isEmpty, segments.allSatisfy(isPlainName) else { return nil }
        let name = segments[segments.count - 1]
        guard servedExtensions.contains((name as NSString).pathExtension.lowercased()) else { return nil }
        return directory + segments.joined(separator: "/")
    }

    // Hidden names (a leading dot) include "." and "..".
    private static func isPlainName(_ segment: String) -> Bool {
        !segment.isEmpty
            && !segment.hasPrefix(".")
            && !segment.contains("/")
            && !segment.contains("\\")
            && !segment.contains("\0")
    }
}
