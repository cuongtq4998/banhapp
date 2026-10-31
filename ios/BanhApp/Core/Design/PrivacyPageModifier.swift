import SafariServices
import SwiftUI

extension View {
    /// Presents the privacy page in the in-app browser and shows `ERR_OPEN_PRIVACY` when it cannot open.
    func privacyPage(_ link: PrivacyLink) -> some View {
        modifier(PrivacyPageModifier(link: link))
    }
}

private struct PrivacyPageModifier: ViewModifier {
    @Bindable var link: PrivacyLink

    func body(content: Content) -> some View {
        content
            .toast(Binding(
                get: { link.failed ? OrderStrings.errorOpenPrivacy : nil },
                set: { if $0 == nil { link.failed = false } }
            ))
            .fullScreenCover(isPresented: Binding(get: { link.presented != nil }, set: { if !$0 { link.dismiss() } })) {
                if let url = link.presented {
                    if link.usesStubBrowser {
                        StubBrowser(close: link.dismiss)
                    } else {
                        SafariView(url: url).ignoresSafeArea()
                    }
                }
            }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Stand-in for the browser in UI tests: no network, one close control.
private struct StubBrowser: View {
    let close: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text(verbatim: "Privacy page")
                .accessibilityIdentifier(AccessibilityID.privacyBrowserStub)
            Button(action: close) { Text(verbatim: "Done") }
                .accessibilityIdentifier(AccessibilityID.privacyBrowserStubClose)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surfaceSolid)
    }
}
