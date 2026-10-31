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
    static let orderNext = "order.next"
    static let orderTitle = "order.title"
    static let orderCakeRemovedNotice = "order.cakeRemovedNotice"

    static let qtyTotal = "order.qty.total"
    static let qtySubtotal = "order.qty.subtotal"
    static let qtyMinHint = "order.qty.minHint"

    static let dateMonthTitle = "order.date.month"
    static let dateMonthPrevious = "order.date.previous"
    static let dateMonthNext = "order.date.next"
    static let dateRangeHint = "order.date.rangeHint"
    static let dateEmptyNotice = "order.date.empty"
    static let dateEmptyAction = "order.date.emptyAction"
    static let dateLoading = "order.date.loading"
    static let dateClearedNotice = "order.date.cleared"
    static let dateNextHint = "order.date.hint"

    static let fieldName = "order.field.name"
    static let fieldPhone = "order.field.phone"
    static let fieldAddress = "order.field.address"
    static let fieldDistrict = "order.field.district"
    static let fieldNote = "order.field.note"
    static let noteCounter = "order.note.counter"
    static let districtFee = "order.district.fee"
    static let districtEmpty = "order.district.empty"
    static let districtError = "order.district.error"

    static let privacyCard = "order.privacy.card"
    static let privacyTitle = "order.privacy.title"
    static let privacyBody = "order.privacy.body"
    static let privacyDraft = "order.privacy.draft"
    static let privacyLink = "order.privacy.link"
    /// Debug-only stand-in for the in-app browser in UI tests.
    static let privacyBrowserStub = "privacy.browser.stub"
    static let privacyBrowserStubClose = "privacy.browser.stub.close"

    static let reviewTotal = "review.total"
    static let reviewFee = "review.fee"
    static let reviewDate = "review.date"
    static let reviewTime = "review.time"
    static let reviewName = "review.name"
    static let reviewPhone = "review.phone"
    static let reviewAddress = "review.address"
    static let reviewNote = "review.note"
    static let reviewPrivacy = "review.privacy"
    static let reviewPrivacyLink = "review.privacy.link"
    static let reviewConfirm = "review.confirm"
    static let reviewMessage = "review.message"
    static let reviewMessageAction = "review.messageAction"
    static let reviewEditCakes = "review.edit.cakes"
    static let reviewEditDate = "review.edit.date"
    static let reviewEditRecipient = "review.edit.recipient"

    /// Zero-cake `StateView` of S-5 (`PRODUCTS_EMPTY`).
    static let emptyState = "state.empty"

    /// Round back button of S-3 and S-4 (the navigation bar is hidden there).
    static let backButton = "nav.back"

    /// Error state of any screen and its retry button.
    static let errorState = "state.error"
    static let errorRetry = "state.retry"

    /// Short notice at the top of a screen (for example a link that could not be opened).
    static let toast = "state.toast"

    static func productCard(_ productID: String) -> String { "products.card.\(productID)" }
    static func productCardSkeleton(_ index: Int) -> String { "products.skeleton.\(index)" }

    /// `<id>` is the cake id, `<date>` is `YYYY-MM-DD`, the other ids are those of the API.
    static func qtyIncrease(_ productID: String) -> String { "order.qty.\(productID).inc" }
    static func qtyDecrease(_ productID: String) -> String { "order.qty.\(productID).dec" }
    static func qtyValue(_ productID: String) -> String { "order.qty.\(productID).value" }
    static func dateCell(_ iso: String) -> String { "order.date.\(iso)" }
    static func slotChip(_ slotID: String) -> String { "order.slot.\(slotID)" }
    static func districtRow(_ districtID: String) -> String { "order.district.row.\(districtID)" }
    static func fieldError(_ field: String) -> String { "order.error.\(field)" }
    static func reviewItem(_ productID: String) -> String { "review.item.\(productID)" }
}

/// Launch arguments that only a debug build reads (see `Debug/UITestStub.swift`); shared so the UI
/// tests pass exactly what the app expects.
nonisolated enum LaunchArgument {
    /// `-BanhStubBackend <mode>` replaces the network with an in-process stub (debug builds only).
    static let stubBackend = "BanhStubBackend"
    static let stubModeCatalog = "catalog"
    static let stubModeUnavailable = "unavailable"
    /// The catalog loads but `GET /v1/availability` fails (S-6 error state).
    static let stubModeAvailabilityFails = "availabilityFails"
    /// Catalog as usual, but the privacy page address is unusable, so opening it fails.
    static let stubModePrivacyFails = "privacyFails"
}
