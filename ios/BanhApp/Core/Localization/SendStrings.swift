import Foundation

/// Display text of sending the order and of the confirmation (S-8 send states and S-9), one constant
/// per key of docs/design/place-order-ui/08-copy.md, resolved through `Localizable.xcstrings` like
/// `OrderStrings`. Placeholders of the document ({date}, {days}, {max}, {code}) are `%@` and `%lld`.
enum SendStrings {
    static let sending = LocalizedStringResource("BTN_SENDING")
    static let errorDateCapacity = LocalizedStringResource("ERR_DATE_CAPACITY")
    static let errorDateLead = LocalizedStringResource("ERR_DATE_LEAD")
    static let errorDateHorizon = LocalizedStringResource("ERR_DATE_HORIZON")
    static let errorOffline = LocalizedStringResource("ERR_OFFLINE")
    static let errorServer = LocalizedStringResource("ERR_SERVER")
    static let errorTimeout = LocalizedStringResource("ERR_TIMEOUT")
    static let errorRateLimited = LocalizedStringResource("ERR_RATE_LIMITED")
    static let priceChanged = LocalizedStringResource("MSG_PRICE_CHANGED")

    static let confirmationTitle = LocalizedStringResource("CONF_TITLE")
    static let confirmationCodeLabel = LocalizedStringResource("CONF_CODE_LABEL")
    static let confirmationCodeSpoken = LocalizedStringResource("CONF_CODE_A11Y")
    static let confirmationMessage = LocalizedStringResource("CONF_MESSAGE")
    static let confirmationHome = LocalizedStringResource("CONF_BTN_HOME")
}
