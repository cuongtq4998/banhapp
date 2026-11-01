#if DEBUG
import SwiftUI

/// UI tests cannot drive the system photo picker (another process). With the stub backend this button
/// stands in for it and "picks" a generated photo; the rest of the path (re-encoding, upload) is real.
struct DebugPickButton: View {
    @Bindable var model: CakeFormViewModel

    var body: some View {
        Button("pick test photo") {
            Task { await model.pick(Self.photo(side: 3000)) }
        }
        .accessibilityIdentifier("admin.cakeForm.debugPick")
        Button("pick broken file") { Task { await model.pick(Data("not an image".utf8)) } }
            .accessibilityIdentifier("admin.cakeForm.debugPickBroken")
    }

    /// A fake cake picture: pink and cream bands, `side` by two thirds of `side` pixels.
    static func photo(side: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: side, height: side * 2 / 3)
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor(red: 1, green: 0.85, blue: 0.9, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.98, green: 0.93, blue: 0.8, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2))
        }
    }
}
#endif
