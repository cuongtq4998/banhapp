import BanhContracts
import SwiftUI

/// S-2: shop name, greeting, Zalo and phone shortcuts, entry to the products and to ordering.
struct HomeView: View {
    private static let zaloSymbol = "message.fill"
    private static let phoneSymbol = "phone.fill"

    @State var model: HomeViewModel
    let onViewProducts: () -> Void
    let onPlaceOrder: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                content
                contactRow
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.xl)
        }
        .bottomActionBar {
            Group {
                ActionButton(title: Strings.homeButtonOrder, action: onPlaceOrder)
                    .accessibilityIdentifier(AccessibilityID.homeOrder)
                ActionButton(title: Strings.homeButtonProducts, emphasis: .secondary, action: onViewProducts)
                    .accessibilityIdentifier(AccessibilityID.homeProducts)
            }
            .disabled(!model.actionsEnabled)
        }
        .toast(toastMessage)
        .appBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .ready(let shop): shopHeader(shop)
        case .loading: skeleton
        case .failed: ErrorStateView(message: Strings.homeError) { Task { await model.retry() } }
        }
    }

    private func shopHeader(_ shop: CatalogShop) -> some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                LogoMark(scale: .small)
                Text(verbatim: shop.name)
                    .font(Typography.titleLarge)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(AccessibilityID.homeShopName)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassCard {
                Text(verbatim: shop.greeting)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityIdentifier(AccessibilityID.homeGreeting)
            }
        }
    }

    private var skeleton: some View {
        VStack(spacing: Spacing.lg) {
            SkeletonBlock().frame(height: Size.logoSmall)
            SkeletonBlock(cornerRadius: Radius.card).frame(height: Size.thumb)
        }
        .loadingAnnouncement(identifier: AccessibilityID.homeSkeleton)
    }

    private var contactRow: some View {
        AdaptiveStack {
            ActionButton(title: Strings.homeButtonZalo, systemImage: Self.zaloSymbol, emphasis: .secondary) {
                Task { await model.openZalo() }
            }
            .accessibilityIdentifier(AccessibilityID.homeZalo)
            ActionButton(title: Strings.homeButtonPhone, systemImage: Self.phoneSymbol, emphasis: .secondary) {
                Task { await model.openPhone() }
            }
            .accessibilityIdentifier(AccessibilityID.homePhone)
        }
        .disabled(!model.actionsEnabled)
    }

    private var toastMessage: Binding<LocalizedStringResource?> {
        Binding(
            get: { model.contact.failure?.message },
            set: { if $0 == nil { model.contact.failure = nil } }
        )
    }
}
