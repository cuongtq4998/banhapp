// swift-tools-version:6.0
import PackageDescription

// Foundation-only on purpose: the iOS app and the backend both import this
// package, and neither may inherit the other's dependencies (ADR-0001).
let package = Package(
    name: "BanhContracts",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BanhContracts", targets: ["BanhContracts"])
    ],
    targets: [
        .target(name: "BanhContracts"),
        .testTarget(
            name: "BanhContractsTests",
            dependencies: ["BanhContracts"]
        )
    ]
)
