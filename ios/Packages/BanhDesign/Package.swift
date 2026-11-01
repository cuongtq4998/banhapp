// swift-tools-version:6.2
import PackageDescription

// Design tokens and components of the admin app (ADR-0021, design-system parts 1 to 7). SwiftUI only.
// Fonts, strings and assets stay in each app; components take text as parameters (ADR-0018). The
// customer app keeps its own copy for now (see docs/engineering/dev-guide.md).
let package = Package(
    name: "BanhDesign",
    platforms: [.iOS(.v17)],
    products: [.library(name: "BanhDesign", targets: ["BanhDesign"])],
    targets: [
        .target(name: "BanhDesign", swiftSettings: [.defaultIsolation(MainActor.self)]),
        .testTarget(name: "BanhDesignTests", dependencies: ["BanhDesign"]),
    ],
    swiftLanguageModes: [.v5]
)
