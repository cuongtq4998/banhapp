import Vapor

/// Serves one file from disk with a fixed `Cache-Control`.
///
/// `FileIO` adds `Content-Type`, `ETag` and `Last-Modified` and answers 304
/// to a matching `If-None-Match`, so only the cache policy is ours.
struct StaticFileResponder {
    let cacheControl: String

    /// - Throws: an uncached `NOT_FOUND` when the path is
    ///   not a regular file.
    func respond(to request: Request, withFileAt path: String) async throws -> Response {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw APIError(.notFound)
        }
        let response = try await request.fileio.asyncStreamFile(at: path)
        response.headers.replaceOrAdd(name: .cacheControl, value: cacheControl)
        return response
    }
}
