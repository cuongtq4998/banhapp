import SwiftUI

/// One cake in the list (`ProductCard`): picture, name, description (two lines), price, chevron.
struct ProductCard: View {
    private static let collapsedDescriptionLines = 2

    let item: ProductItem
    @ScaledMetric(relativeTo: .body) private var thumbSize = Size.thumb
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassCard(padding: Spacing.md) {
            AdaptiveStack(spacing: Spacing.inner, verticalAlignment: .center) {
                ProductImage(url: item.imageURL, accessibilityName: item.name)
                    .frame(width: thumbSize, height: thumbSize)
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(verbatim: item.name)
                            .textStyle(Typography.cardTitle)
                            .foregroundStyle(Palette.textPrimary)
                        Text(verbatim: item.description)
                            .textStyle(Typography.cardDescription)
                            .foregroundStyle(Palette.textSecondary)
                            // At accessibility sizes nothing is cut off (design system principle 5).
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : Self.collapsedDescriptionLines)
                        Text(verbatim: Strings.priceEach(amount: item.priceText))
                            .textStyle(Typography.listPrice)
                            .foregroundStyle(Palette.primaryDeep)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: Size.chevronRow, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityHidden(true)
                }
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
        GlassCard(padding: Spacing.md) {
            HStack(spacing: Spacing.inner) {
                SkeletonBlock(cornerRadius: Radius.thumb).frame(width: thumbSize, height: thumbSize)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SkeletonBlock().frame(height: Spacing.lg)
                    SkeletonBlock().frame(height: Spacing.lg)
                }
            }
        }
        .loadingAnnouncement(identifier: AccessibilityID.productCardSkeleton(index))
    }
}
