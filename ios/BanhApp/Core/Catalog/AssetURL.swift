import Foundation

nonisolated extension URL {
    /// Resolves an `image_url` of the catalog against the API address. The `?v=` content version of
    /// ADR-0017 stays in the result, so a changed photo is fetched again. A full URL is kept as it is.
    func resolvingAsset(_ imageURL: String) -> URL? {
        URL(string: imageURL, relativeTo: self)?.absoluteURL
    }
}
