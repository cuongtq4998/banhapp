import SwiftUI

/// A cake picture. A failed picture shows a placeholder icon in the same frame and keeps the card
/// usable (UI document 5.3). Loading goes through the system URL cache (ADR-0011), which honours the
/// one-year `immutable` header of the versioned URL (ADR-0017).
struct ProductImage: View {
    private static let placeholderSymbol = "photo"

    let url: URL?
    /// Spoken label of a loaded picture: the cake name.
    let accessibilityName: String
    var cornerRadius: CGFloat = Radius.image

    var body: some View {
        content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill().accessibilityLabel(accessibilityName)
                case .failure:
                    placeholder
                default:
                    SkeletonBlock(cornerRadius: cornerRadius)
                }
            }
        } else {
            // An `image_url` that cannot form a URL will never load, so show the failed state at once.
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Palette.primaryContainer
            Image(systemName: Self.placeholderSymbol)
                .font(.title)
                .foregroundStyle(Palette.onPrimaryContainer)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Strings.productImageFailed))
    }
}
