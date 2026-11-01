import Foundation
import FluentSQL

/// A cake of the owner's list as the database holds it. A cake that came
/// with the sample data has a file path; an uploaded one has an image row, and
/// its version is the first 8 characters of the image hash (ADR-0025).
struct CakeRow: Decodable {
    static let select: SQLQueryString = """
        SELECT p.id AS cake_id, p.name, p.description, p.price_vnd, p.is_active, p.image_path, left(i.sha256, 8) AS image_version
        FROM product p LEFT JOIN product_image i ON i.product_id = p.id
        """

    let cakeID: UUID
    let name: String
    let description: String
    let priceVND: Int
    let isActive: Bool
    let imagePath: String?
    let imageVersion: String?

    private enum CodingKeys: String, CodingKey {
        case cakeID = "cake_id", name, description, priceVND = "price_vnd", isActive = "is_active"
        case imagePath = "image_path", imageVersion = "image_version"
    }

    func view(_ assets: AssetURLBuilder) -> CakeView {
        CakeView(cakeID: cakeID, name: name, description: description, priceVND: priceVND, isActive: isActive,
                 imageURL: assets.imageURL(forPath: imagePath ?? AssetURLBuilder.uploadedPath(of: cakeID), uploadVersion: imageVersion))
    }
}
