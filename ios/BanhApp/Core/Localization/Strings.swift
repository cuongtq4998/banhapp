import Foundation

/// Display text of slice 1, one constant per key of docs/design/place-order-ui.md section 8. The raw key
/// is written once here and resolved through `Localizable.xcstrings` (Vietnamese is the only language,
/// ADR-0007). Views use these constants, never string literals, so a typo fails to compile.
enum Strings {
    static let logoLabel = LocalizedStringResource("LOGO_LABEL")

    static let homeButtonZalo = LocalizedStringResource("HOME_BTN_ZALO")
    static let homeButtonPhone = LocalizedStringResource("HOME_BTN_PHONE")
    static let homeButtonProducts = LocalizedStringResource("HOME_BTN_PRODUCTS")
    static let homeButtonOrder = LocalizedStringResource("HOME_BTN_ORDER")
    static let homeError = LocalizedStringResource("HOME_ERR")
    static let errorOpenZalo = LocalizedStringResource("ERR_OPEN_ZALO")
    static let errorOpenPhone = LocalizedStringResource("ERR_OPEN_PHONE")

    static let errorNetworkLoad = LocalizedStringResource("ERR_NETWORK_LOAD")
    static let commonRetry = LocalizedStringResource("COMMON_RETRY")
    static let commonLoading = LocalizedStringResource("COMMON_LOADING")

    static let productsTitle = LocalizedStringResource("PRODUCTS_TITLE")
    static let productsError = LocalizedStringResource("PRODUCTS_ERR")
    static let productImageFailed = LocalizedStringResource("PRODUCT_IMG_FAILED")
    static let detailButtonOrder = LocalizedStringResource("DETAIL_BTN_ORDER")

    static let flowTitle = LocalizedStringResource("FLOW_TITLE")
    static let step1 = LocalizedStringResource("STEP1")

    /// `PRICE_EACH`: "{amount}/cái". The amount is already formatted by `MoneyFormatter`.
    static func priceEach(amount: String) -> String {
        String(format: String(localized: LocalizedStringResource("PRICE_EACH")), amount)
    }

    /// `STEP_LABEL`: "Bước {n}/4".
    static func stepLabel(step: Int) -> String {
        String(format: String(localized: LocalizedStringResource("STEP_LABEL")), step)
    }

    /// Message of a failed catalog load on S-3 to S-5: the network message offline, the screen's own otherwise (UI document 5.10).
    static func catalogLoadFailure(_ failure: LoadFailure, screenMessage: LocalizedStringResource) -> LocalizedStringResource {
        switch failure {
        case .network: errorNetworkLoad
        case .other: screenMessage
        }
    }
}
