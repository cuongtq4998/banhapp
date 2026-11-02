import BanhCore
import BanhDesign
import SwiftUI

/// S-A4 Order detail with the action bar; S-A5 opens as a sheet.
struct OrderDetailView: View {
    @Bindable var model: OrderDetailViewModel
    /// Server date of the list the order came from, for the due mark.
    let serverDate: String
    let opener: any URLOpener
    let onBackToList: () -> Void

    var body: some View {
        content
            .appBackground()
            .customBackNavigation()
            .toast($model.toast, identifier: AdminID.toast)
            .task { await model.load() }
            .sensoryFeedback(.success, trigger: model.successCount)
            .sensoryFeedback(.error, trigger: model.failureCount)
            .sheet(isPresented: $model.showsCancelSheet) { CancelSheet(model: model) }
            .alert(
                AStrings.completeTitle(code: model.code), isPresented: $model.showsFinishDialog
            ) {
                Button(String(localized: AStrings.back), role: .cancel) {}
                    .accessibilityIdentifier(AdminID.detailCompleteBack)
                Button(String(localized: AStrings.completeYes)) { Task { await model.finish() } }
                    .accessibilityIdentifier(AdminID.detailCompleteYes)
            } message: {
                Text(AStrings.completeBody)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            page { VStack(spacing: Spacing.md) { ForEach(0..<3, id: \.self) { _ in SkeletonBlock().frame(height: 120) } }
                .accessibilityElement(children: .ignore).accessibilityIdentifier(AdminID.detailSkeleton) }
        case .gone:
            page {
                StateView(
                    symbol: "questionmark.folder", message: AStrings.orderGone,
                    actionTitle: AStrings.backToList, actionIdentifier: AdminID.detailRetry, action: onBackToList
                )
                .accessibilityElement(children: .contain).accessibilityIdentifier(AdminID.detailGone)
            }
        case .failed(let failure):
            page {
                StateView(
                    message: failure == .network ? AStrings.offline : AStrings.errGeneric,
                    actionTitle: AStrings.retry, actionIdentifier: AdminID.detailRetry
                ) { Task { await model.load() } }
                .accessibilityElement(children: .contain).accessibilityIdentifier(AdminID.detailError)
            }
        case .loaded(let detail):
            page {
                if let text = model.messageText { message(text) }
                DetailCards(
                    detail: detail,
                    due: DueState.of(status: detail.status, deliveryDate: detail.deliveryDate, serverDate: serverDate),
                    opener: opener, toast: $model.toast
                )
            }
            .bottomActionBar { ActionBar(model: model, detail: detail) }
        }
    }

    private func page<Body: View>(@ViewBuilder _ body: () -> Body) -> some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                titleRow
                body()
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.xl)
        }
    }

    private var titleRow: some View {
        HStack(spacing: Spacing.md) {
            BackButton(label: AStrings.back, identifier: AdminID.navBack)
            Text(verbatim: model.code).textStyle(Typography.display).textSelection(.enabled)
                .foregroundStyle(Palette.textPrimary).accessibilityIdentifier(AdminID.detailCode)
            Spacer(minLength: Spacing.sm)
            if let detail = model.detail {
                StatusBadge(tone: detail.status.tone, text: String(localized: AStrings.status(detail.status)))
                    .accessibilityIdentifier(AdminID.detailStatus)
            }
        }
        .padding(.top, Spacing.sm)
    }

    private func message(_ text: String) -> some View {
        let isConflict: Bool = if case .conflict? = model.actionMessage { true } else { false }
        return InlineMessage(kind: isConflict ? .warning : .error, text: text)
            .accessibilityIdentifier(isConflict ? AdminID.detailConflict : AdminID.detailError)
    }
}

/// The bottom bar: only the actions the server allows (the sheets for dates and fees are a later slice).
private struct ActionBar: View {
    @Bindable var model: OrderDetailViewModel
    let detail: OrderDetail

    var body: some View {
        if detail.allows(.cancel) || detail.allows(.process) || detail.allows(.finish) {
            AdaptiveStack(spacing: Spacing.md) {
                if detail.allows(.cancel) {
                    ActionButton(title: AStrings.cancelOrder, emphasis: .destructive) { model.showsCancelSheet = true }
                        .disabled(model.isBusy)
                        .accessibilityIdentifier(AdminID.detailCancel)
                }
                if detail.allows(.process) {
                    ActionButton(title: AStrings.confirmOrder, showsProgress: model.running == .process) {
                        Task { await model.process() }
                    }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier(AdminID.detailConfirm)
                }
                if detail.allows(.finish) {
                    ActionButton(title: AStrings.completeOrder, showsProgress: model.running == .finish) {
                        model.showsFinishDialog = true
                    }
                    .disabled(model.isBusy)
                    .accessibilityIdentifier(AdminID.detailComplete)
                }
            }
        }
    }
}
