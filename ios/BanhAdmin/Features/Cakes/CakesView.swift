import BanhCore
import BanhDesign
import SwiftUI

/// S-A7 Cakes: count pill, add button, list of cake rows.
struct CakesView: View {
    @Bindable var model: CakesViewModel
    let onBack: () -> Void
    let onAdd: () -> Void
    let onOpen: (Cake) -> Void
    let baseURL: URL

    var body: some View {
        SettingsScaffold(title: String(localized: AStrings.rowCakes), screen: AdminOwnerID.cakes, onBack: onBack, showsBar: false) {
            LoadStateView(load: model.load, screen: AdminOwnerID.cakes, retry: { Task { await model.retry() } }) { _ in
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(verbatim: AStrings.cakesCount(model.cakes.count)).textStyle(Typography.bodyStrong)
                        .padding(.horizontal, Spacing.md).frame(minHeight: 32)
                        .background(Palette.chipFill, in: Capsule())
                        .accessibilityIdentifier(AdminOwnerID.cakesCount)
                    ActionButton(title: AStrings.addCake, systemImage: "plus", action: onAdd)
                        .disabled(model.isFull)
                        .accessibilityIdentifier(AdminOwnerID.cakesAdd)
                    if model.isFull {
                        Text(AStrings.cakesFull).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                            .accessibilityIdentifier(AdminOwnerID.cakesFull)
                    }
                    if model.cakes.isEmpty {
                        StateView(symbol: "birthday.cake", message: AStrings.cakesEmpty)
                            .accessibilityIdentifier(AdminOwnerID.cakesEmpty)
                    }
                    ForEach(model.cakes) { cake in
                        Button { onOpen(cake) } label: { CakeRow(cake: cake, baseURL: baseURL) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AdminOwnerID.cakeRow(cake.id))
                    }
                }
            }
        } bar: { EmptyView() }
        .task { await model.reload() }
    }
}

/// One cake: thumbnail, name, price and the status badge; hidden cakes are dimmed to 70%.
struct CakeRow: View {
    let cake: Cake
    let baseURL: URL

    var body: some View {
        GlassCard(padding: Spacing.md) {
            HStack(spacing: Spacing.md) {
                CakeThumbnail(path: cake.imageUrl, baseURL: baseURL).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(verbatim: cake.name).textStyle(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
                    Text(verbatim: MoneyFormatter.format(cake.priceVnd)).textStyle(Typography.bodyStrong)
                        .foregroundStyle(Palette.textPrimary)
                }
                Spacer(minLength: Spacing.sm)
                StatusBadge(
                    tone: cake.isActive ? .confirmed : .completed,
                    text: String(localized: cake.isActive ? AStrings.cakeActive : AStrings.cakeHidden)
                )
            }
        }
        .opacity(cake.isActive ? 1 : 0.7)
        .accessibilityElement(children: .combine)
    }
}

/// The picture of a cake from `image_url` (a path on the API host); a placeholder with the label when it fails.
struct CakeThumbnail: View {
    let path: String
    let baseURL: URL

    var body: some View {
        AsyncImage(url: URL(string: path, relativeTo: baseURL)) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .failure:
                placeholder.accessibilityLabel(Text(AStrings.imgFailedA11y))
            default: placeholder.overlay { ProgressView() }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: Radius.field, style: .continuous).fill(Palette.chipFill)
            .overlay { Image(systemName: "photo").foregroundStyle(Palette.textSecondary) }
    }
}
