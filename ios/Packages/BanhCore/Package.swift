// swift-tools-version:6.2
import PackageDescription

// Shared pure logic of the iOS apps (ADR-0021): money format, Load state, HTTP client with the error
// envelope. Foundation only; no resources and no strings (those stay in each app, ADR-0018).
let package = Package(
    name: "BanhCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "BanhCore", targets: ["BanhCore"])],
    dependencies: [.package(path: "../../../contracts/swift")],
    targets: [
        .target(
            name: "BanhCore",
            dependencies: [.product(name: "BanhContracts", package: "swift")]
        ),
        .testTarget(name: "BanhCoreTests", dependencies: ["BanhCore"]),
    ],
    swiftLanguageModes: [.v5]
)
