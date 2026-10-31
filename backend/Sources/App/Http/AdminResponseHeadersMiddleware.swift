import Vapor

/// Every `/v1/auth`, `/v1/admin` and `/v1/owner` response, error or not, is
/// `no-store` and varies by `Authorization` (api/05 section 9).
struct AdminResponseHeadersMiddleware: AsyncMiddleware {
    static let vary = "Authorization"

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response: Response
        do {
            response = try await next.respond(to: request)
        } catch let error as APIError {
            var headers = error.headers
            headers[HTTPHeaders.Name.cacheControl.description] = APIError.noStoreCacheControl
            headers[HTTPHeaders.Name.vary.description] = Self.vary
            throw APIError(error.code, fields: error.fields, details: error.details, headers: headers)
        }
        response.headers.replaceOrAdd(name: .cacheControl, value: APIError.noStoreCacheControl)
        response.headers.replaceOrAdd(name: .vary, value: Self.vary)
        return response
    }
}
