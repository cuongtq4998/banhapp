import BanhCore
import BanhDesign
import SwiftUI

/// Frame of every pushed owner screen: round back button and title, scrolling content, optional
/// floating bar for the save button. The system bar is hidden and the swipe-back gesture stays off,
/// so a form with unsaved changes can only be left through the dirty dialog.
struct SettingsScaffold<Content: View, Bar: View>: View {
    let title: String
    let screen: String
    let onBack: () -> Void
    var showsBar = true
    @ViewBuilder var content: Content
    @ViewBuilder var bar: Bar

    var body: some View {
        ScrollViewReader { proxy in scroll.environment(\.formScroll, proxy) }
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    BackButton(label: AStrings.back, identifier: AdminOwnerID.back(screen), action: onBack)
                    Text(verbatim: title).textStyle(Typography.heading).foregroundStyle(Palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                }
                content
            }
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .appBackground()
        .modifier(OptionalBar(showsBar: showsBar, bar: bar))
    }
}

private struct OptionalBar<Bar: View>: ViewModifier {
    let showsBar: Bool
    let bar: Bar

    func body(content: Content) -> some View {
        if showsBar { content.bottomActionBar { bar } } else { content }
    }
}

/// Skeleton while loading, `StateView` with retry when the data cannot be had, the content when ready.
struct LoadStateView<Value, Content: View>: View {
    let load: Load<Value>
    let screen: String
    let retry: () -> Void
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch load {
        case .loading:
            VStack(spacing: Spacing.md) { ForEach(0..<4, id: \.self) { _ in SkeletonBlock().frame(height: 64) } }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(AdminOwnerID.skeleton)
        case .failed(let failure):
            StateView(
                message: failure == .network ? AStrings.offline : AStrings.errGeneric,
                actionTitle: AStrings.retry, actionIdentifier: AdminOwnerID.retry, action: retry
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(failure == .network ? AdminOwnerID.offline : AdminOwnerID.error)
        case .ready(let value):
            content(value)
        }
    }
}

/// `LoadFailure` of a thrown error (no connection or other).
extension Error {
    nonisolated var loadFailure: LoadFailure { (self as? APIError)?.isConnectivity == true ? .network : .other }
}

/// Dirty back dialog (part 2): shown instead of leaving a form with unsaved changes.
extension View {
    func discardDialog(isPresented: Binding<Bool>, discard: @escaping () -> Void) -> some View {
        alert(String(localized: AStrings.discardTitle), isPresented: isPresented) {
            Button(String(localized: AStrings.keepEditing), role: .cancel) {}
                .accessibilityIdentifier(AdminOwnerID.discardKeep)
            Button(String(localized: AStrings.discard), role: .destructive, action: discard)
                .accessibilityIdentifier(AdminOwnerID.discardConfirm)
        } message: { Text(AStrings.discardBody) }
    }
}
