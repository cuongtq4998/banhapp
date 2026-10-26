/// Accessibility identifiers, the selectors of the UI tests. The one list the app and the UI test
/// target both compile (folder `Shared`), so a rename cannot leave a test behind. The values mirror
/// `android/.../TestTags.kt` so one test description fits both platforms.
nonisolated enum AccessibilityID {
    static let launchLogo = "launch.logo"

    static let homeShopName = "home.shopName"
    static let homeGreeting = "home.greeting"
    static let homeZalo = "home.zaloButton"
    static let homePhone = "home.phoneButton"
    static let homeProducts = "home.productsButton"
    static let homeOrder = "home.orderButton"
    static let homeSkeleton = "home.skeleton"

    static let productsList = "products.list"
    static let productsOrder = "products.orderButton"

    static let detailName = "detail.name"
    static let detailDescription = "detail.description"
    static let detailPrice = "detail.price"
    static let detailSkeleton = "detail.skeleton"
    static let detailOrder = "detail.orderButton"

    static let orderStep = "order.step"

    /// Round back button of S-3 and S-4 (the navigation bar is hidden there).
    static let backButton = "nav.backButton"

    /// Error state of any screen and its retry button.
    static let errorState = "state.error"
    static let errorRetry = "state.retry"

    /// Short notice at the top of a screen (for example a link that could not be opened).
    static let toast = "state.toast"

    static func productCard(_ productID: String) -> String { "products.card.\(productID)" }
    static func productCardSkeleton(_ index: Int) -> String { "products.skeleton.\(index)" }
}

/// Launch arguments that only a debug build reads (see `Debug/UITestStub.swift`); shared so the UI
/// tests pass exactly what the app expects.
nonisolated enum LaunchArgument {
    /// `-BanhStubBackend <mode>` replaces the network with an in-process stub (debug builds only).
    static let stubBackend = "BanhStubBackend"
    static let stubModeCatalog = "catalog"
    static let stubModeUnavailable = "unavailable"
}
