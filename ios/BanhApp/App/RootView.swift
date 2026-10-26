import SwiftUI

/// Empty app shell (ADR-0007). Real screens arrive with slice 1; this view only proves
/// that the app builds, launches and resolves strings from the catalog.
struct RootView: View {
    var body: some View {
        Text("shell.placeholder")
            .padding()
    }
}

#Preview {
    RootView()
}
