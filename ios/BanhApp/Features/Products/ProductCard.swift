import SwiftUI

/// One cake in the list (`ProductCard`): picture, name, description (two lines), price.
struct ProductCard: View {
    private static let collapsedDescriptionLines = 2

    let item: ProductItem
    @ScaledMetric(relativeTo: .body) private var thumbSize = Size.thumb
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassCard {
            AdaptiveStack(spacing: Spacing.md, verticalAlignment: .top) {
                ProductImage(url: item.imageURL, accessibilityName: item.name)
                    .frame(width: thumbSize, height: thumbSize)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(verbatim: item.name)
                        .font(Typography.titleMedium)
                        .foregroundStyle(Palette.textPrimary)
                    Text(verbatim: item.description)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                        // At accessibility sizes nothing is cut off (design system principle 5).
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : Self.collapsedDescriptionLines)
                    Text(verbatim: Strings.priceEach(amount: item.priceText))
                        .font(Typography.bodyStrong)
                        .foregroundStyle(Palette.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Placeholder card with the same footprint as `ProductCard`.
struct ProductCardSkeleton: View {
    let index: Int
    @ScaledMetric(relativeTo: .body) private var thumbSize = Size.thumb

    var body: some View {
        GlassCard {
            HStack(spacing: Spacing.md) {
                SkeletonBlock(cornerRadius: Radius.image).frame(width: thumbSize, height: thumbSize)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonBlock().frame(height: Spacing.lg)
                    SkeletonBlock().frame(height: Spacing.lg)
                }
            }
        }
        .loadingAnnouncement(identifier: AccessibilityID.productCardSkeleton(index))
    }
}
