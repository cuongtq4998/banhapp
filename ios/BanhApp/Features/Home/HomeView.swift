import BanhContracts
import SwiftUI

/// S-2: shop name, greeting, entry to the products and to ordering, Zalo and phone shortcuts.
struct HomeView: View {
    private static let zaloSymbol = "message"
    private static let phoneSymbol = "phone"

    @State var model: HomeViewModel
    let onViewProducts: () -> Void
    let onPlaceOrder: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.tileGap) {
                content
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.homeHeaderTop)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { contactRow }
        .toast(toastMessage)
        .appBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .ready(let shop):
            shopHeader(shop)
            tiles
        case .loading:
            skeleton
            tiles
        case .failed:
            ErrorStateView(message: Strings.homeError) { Task { await model.retry() } }
            tiles
        }
    }

    private func shopHeader(_ shop: CatalogShop) -> some View {
        VStack(spacing: Spacing.inner) {
            LogoMark(scale: .small)
            Text(verbatim: shop.name)
                .textStyle(Typography.heroTitle)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(AccessibilityID.homeShopName)
            Text(verbatim: shop.greeting)
                .textStyle(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: Spacing.greetingMaxWidth)
                .accessibilityIdentifier(AccessibilityID.homeGreeting)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.tilesTop - Spacing.tileGap)
    }

    private var skeleton: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonBlock(cornerRadius: Radius.logoSmall).frame(width: Size.logoSmall, height: Size.logoSmall)
            SkeletonBlock(cornerRadius: Radius.card).frame(height: Size.thumb)
        }
        .padding(.bottom, Spacing.tilesTop - Spacing.tileGap)
        .loadingAnnouncement(identifier: AccessibilityID.homeSkeleton)
    }

    /// Both tiles are always present; they stay disabled until the shop information is shown.
    private var tiles: some View {
        GlassGroup {
            VStack(spacing: Spacing.tileGap) {
                ActionTile(title: Strings.homeButtonProducts, hint: productsHint, action: onViewProducts)
                    .accessibilityIdentifier(AccessibilityID.homeProducts)
                ActionTile(
                    title: Strings.homeButtonOrder,
                    hint: String(localized: Strings.homeOrderHint),
                    emphasis: .primary,
                    action: onPlaceOrder
                )
                .accessibilityIdentifier(AccessibilityID.homeOrder)
            }
        }
        .disabled(!model.actionsEnabled)
    }

    private var productsHint: String {
        model.productCount.map { Strings.homeProductsHint(count: $0) } ?? ""
    }

    private var contactRow: some View {
        GlassGroup {
            AdaptiveStack(spacing: Spacing.contactGap) {
                ActionButton(title: Strings.homeButtonZalo, systemImage: Self.zaloSymbol, emphasis: .secondary) {
                    Task { await model.openZalo() }
                }
                .accessibilityIdentifier(AccessibilityID.homeZalo)
                ActionButton(title: Strings.homeButtonPhone, systemImage: Self.phoneSymbol, emphasis: .secondary) {
                    Task { await model.openPhone() }
                }
                .accessibilityIdentifier(AccessibilityID.homePhone)
            }
        }
        .disabled(!model.actionsEnabled)
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, Size.barFloatOffset)
    }

    private var toastMessage: Binding<LocalizedStringResource?> {
        Binding(
            get: { model.contact.failure?.message },
            set: { if $0 == nil { model.contact.failure = nil } }
        )
    }
}
