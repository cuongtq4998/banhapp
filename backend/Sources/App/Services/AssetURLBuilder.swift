/// Builds the `image_url` of a product from its stored `image_path`
/// (api.md 4.1, 4.6).
struct AssetURLBuilder: Sendable {
    /// The path prefix the asset route serves under; one constant for the
    /// route and for the URLs that point at it.
    static let routeSegment = "assets"
    static let versionQueryName = "v"

    /// Empty for the common case (assets on the API host); a full origin such
    /// as `https://cdn.example` when they move (`PUBLIC_ASSET_BASE_URL`).
    let baseURL: String
    let versions: AssetVersions

    init(baseURL: String, versions: AssetVersions = AssetVersions(hashes: [:])) {
        self.baseURL = baseURL
        self.versions = versions
    }

    /// Whether `imageURL` can name the file's version. False means the file
    /// was not found at start.
    func hasVersion(forPath imagePath: String) -> Bool {
        versions.version(forPath: imagePath) != nil
    }

    func imageURL(forPath imagePath: String) -> String {
        let url = "\(baseURL)/\(Self.routeSegment)/\(imagePath)"
        guard let version = versions.version(forPath: imagePath) else { return url }
        return "\(url)?\(Self.versionQueryName)=\(version)"
    }
}
