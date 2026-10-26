// swift-tools-version:6.0
import PackageDescription

// QA package (probe-qa). It compiles the backend sources (symlinked, without
// the @main entrypoint) next to the QA tests, so the developers' package and
// test target stay untouched. Run from this folder: `swift test`.
// Database-level tests run only when DATABASE_MIGRATION_URL is set.
let package = Package(
    name: "backend-qa",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", exact: "4.122.3"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.0"),
        .package(path: "../../../contracts/swift")
    ],
    targets: [
        .target(
            name: "AppUnderTest",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "BanhContracts", package: "swift")
            ],
            path: "Sources/AppUnderTest",
            exclude: ["entrypoint.swift"]
        ),
        .testTarget(
            name: "QATests",
            dependencies: [
                .target(name: "AppUnderTest"),
                .product(name: "XCTVapor", package: "vapor")
            ],
            path: "Tests/QATests"
        )
    ]
)
