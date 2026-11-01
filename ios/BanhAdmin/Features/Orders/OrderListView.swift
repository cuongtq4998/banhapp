import BanhCore
import BanhDesign
import SwiftUI

/// S-A3 Order list "To do". Staff get the account button and the red number beside the title; the
/// owner's number is on the tab (`ShellView`).
struct OrderListView: View {
    @Bindable var model: OrderListViewModel
    let showsStaffHeader: Bool
    let onOpen: (OrderSummary) -> Void
    let onAccount: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md, pinnedViews: []) {
                header
                OrderFilterBar(model: model)
                content
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.xl)
        }
        .refreshable { await model.reload() }
        .scrollDismissesKeyboard(.immediately)
        .appBackground()
        .task { await model.reloadIfStale() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.reloadIfStale() } }
        }
        .accessibilityIdentifier(AdminID.ordersList)
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Text(AStrings.ordersTitle).textStyle(Typography.screenTitle).foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(AdminID.ordersTitle)
            if showsStaffHeader && model.unfinishedCount > 0 {
                CountBadge(count: model.unfinishedCount)
                    .accessibilityLabel(Text(verbatim: AStrings.tabBadgeA11y(count: model.unfinishedCount)))
                    .accessibilityIdentifier(AdminID.ordersBadge)
            }
            Spacer()
            if showsStaffHeader {
                Button(action: onAccount) {
                    Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(Palette.textPrimary)
                        .frame(width: Size.touchTarget, height: Size.touchTarget).circleGlassSurface()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AStrings.accountA11y))
                .accessibilityIdentifier(AdminID.ordersAccount)
            }
        }
        .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            OrderListSkeleton()
        case .failed(let failure):
            StateView(
                message: failure == .network ? AStrings.offline : AStrings.errGeneric,
                actionTitle: AStrings.retry, actionIdentifier: AdminID.ordersRetry
            ) { Task { await model.reload() } }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(failure == .network ? AdminID.ordersOffline : AdminID.ordersError)
        case .ready:
            if model.rows.isEmpty { emptyState } else { rows }
        }
    }

    private var rows: some View {
        Group {
            ForEach(model.rows) { order in
                Button { onOpen(order) } label: { OrderRowView(order: order, due: model.due(for: order)) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AdminID.row(order.orderCode))
                    .onAppear { model.rowAppeared(order) }
            }
            footer
        }
    }

    @ViewBuilder
    private var footer: some View {
        if model.isLoadingMore {
            ProgressView().frame(maxWidth: .infinity).padding(Spacing.md)
        } else if model.loadMoreFailed {
            HStack {
                Text(AStrings.loadMoreFailed).textStyle(Typography.caption).foregroundStyle(Palette.textSecondary)
                TextLinkButton(AStrings.retry) { Task { await model.loadMore() } }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AdminID.ordersLoadMoreError)
        }
    }

    private var emptyState: some View {
        let text: LocalizedStringResource = switch model.emptyKind {
        case .search: AStrings.searchEmpty
        case .filtered: AStrings.ordersEmpty
        case .todo: AStrings.todoEmpty
        }
        return StateView(
            symbol: model.emptyKind == .todo ? "checkmark.circle" : "tray", message: text,
            actionTitle: model.emptyKind == .filtered ? AStrings.clearFilters : nil,
            actionIdentifier: AdminID.ordersClearFilters
        ) { model.clearFilters() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AdminID.ordersEmpty)
    }
}
