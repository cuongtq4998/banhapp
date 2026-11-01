import UIKit

/// Prepares a picked photo for `POST /v1/owner/cakes` (ADR-0025): always re-encoded as JPEG (so HEIC
/// never reaches the server and location data is dropped), longest side 1600 px, flattened on white,
/// quality lowered until the file is within 5,242,880 bytes. A side under 200 px or over 4096 px is refused.
nonisolated enum CakeImage {
    static let maxBytes = 5_242_880
    static let minSide = 200
    static let maxSide = 4096
    static let targetLongSide: CGFloat = 1600

    enum Failure: Error, Equatable {
        /// Not an image the phone can decode.
        case unreadable
        /// A side under 200 px (`A_ERR_IMG_DIM_SMALL`) or over 4096 px (`A_ERR_IMG_DIM_LARGE`).
        case tooSmall, tooLarge
        /// Still above the byte limit at the lowest quality and smallest size (`A_ERR_IMG_SIZE`).
        case tooManyBytes
    }

    static func prepare(_ data: Data, maxBytes: Int = CakeImage.maxBytes) -> Result<Data, Failure> {
        guard let image = UIImage(data: data) else { return .failure(.unreadable) }
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard Int(min(pixels.width, pixels.height)) >= minSide else { return .failure(.tooSmall) }
        guard Int(max(pixels.width, pixels.height)) <= maxSide else { return .failure(.tooLarge) }
        var longSide = min(max(pixels.width, pixels.height), targetLongSide)
        for _ in 0..<6 {
            let factor = longSide / max(pixels.width, pixels.height)
            let size = CGSize(width: max(CGFloat(minSide), (pixels.width * factor).rounded()), height: max(CGFloat(minSide), (pixels.height * factor).rounded()))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let flat = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            for quality in [0.8, 0.6, 0.4] {
                if let jpeg = flat.jpegData(compressionQuality: quality), jpeg.count <= maxBytes { return .success(jpeg) }
            }
            longSide = (longSide * 0.7).rounded()
        }
        return .failure(.tooManyBytes)
    }
}
