/// Identifiers of S-9 and the launch modes of the order scenarios of the stub backend. Kept apart from
/// `AccessibilityID.swift` (still one list for the app and the UI tests, folder `Shared`). Names follow
/// the rule `<screen>.<element>` of docs/design/place-order-ui/09-accessibility-test-ids.md.
nonisolated extension AccessibilityID {
    static let confirmationTitle = "confirmation.title"
    static let confirmationCode = "confirmation.code"
    static let confirmationMessage = "confirmation.message"
    static let confirmationZalo = "confirmation.zaloButton"
    static let confirmationPhone = "confirmation.phoneButton"
    static let confirmationHome = "confirmation.homeButton"
}

nonisolated extension LaunchArgument {
    /// `-BanhStubBackend order:<scenario>`: the catalog loads and `POST /v1/orders` follows the scenario.
    static let stubOrderPrefix = "order:"

    /// Accepted at once (201, `order-created.json`).
    static let orderSuccess = "success"
    /// Answers after 3 s; a second POST would get another code.
    static let orderSlow = "slow"
    /// First attempt: no connection. The retry succeeds.
    static let orderOffline = "offline"
    /// First attempt: the order is stored but the answer is lost (timeout). The retry with the same key
    /// gets the stored order (200 replay, `order-replay.json`); another key would get another code.
    static let orderLostAnswer = "lostAnswer"
    /// First attempt answers 409 `PRICE_CHANGED`; confirming again at the new total succeeds.
    static let orderPriceChanged = "priceChanged"
    /// First attempt answers with the fixture `order-error-<name>.json`, e.g. `error-min-qty`; later ones succeed.
    static let orderErrorPrefix = "error-"

    static func order(_ scenario: String) -> String { stubOrderPrefix + scenario }

    static let confirmationCode = "BT-7K3M9Q"
    static let otherCode = "BT-OTHER1"
}
