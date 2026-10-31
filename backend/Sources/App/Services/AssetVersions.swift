import Foundation
import Crypto

/// Short content hashes of the product image files, taken once at start.
///
/// The hash goes into `image_url` as `?v=<hash>`, so a changed picture gets a
/// new URL and the images can be cached for a year (api.md 4.6). Computed at
/// start, not per request: the files only change with a deploy.
struct AssetVersions: Sendable {
    /// Length of the hash in `?v=`: enough to tell versions of one file apart.
    static let hexLength = 8
    static let imagesDirectoryName = "images"

    /// Hash by path relative to the assets directory (`images/banana.png`).
    private let hashes: [String: String]

    init(hashes: [String: String]) {
        self.hashes = hashes
    }

    /// Hashes every file under `<assetsDirectory>/images`. A missing or
    /// unreadable directory gives an empty index, and the catalogue then warns
    /// about each product whose image has no hash.
    static func load(fromAssetsDirectory assetsDirectory: String) -> AssetVersions {
        let root = assetsDirectory + imagesDirectoryName
        let names = FileManager.default.enumerator(atPath: root)?.compactMap { $0 as? String } ?? []
        var hashes: [String: String] = [:]
        for name in names {
            guard let data = FileManager.default.contents(atPath: root + "/" + name) else { continue }
            hashes[imagesDirectoryName + "/" + name] = String(SHA256.hash(data: data).hexString.prefix(hexLength))
        }
        return AssetVersions(hashes: hashes)
    }

    func version(forPath imagePath: String) -> String? {
        hashes[imagePath]
    }
}
