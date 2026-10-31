import Foundation

/// Body of `GET /v1/catalog` (api.md 4.1): everything the app shows before an
/// order starts.
public struct CatalogResponse: Codable, Equatable, Sendable {
    /// Today in shop time, `YYYY-MM-DD`. Clients use it instead of the device date.
    public let serverDate: String
    public let shop: CatalogShop
    public let settings: CatalogSettings
    public let products: [CatalogProduct]
    public let districts: [CatalogDistrict]
    public let slots: [CatalogSlot]

    public init(
        serverDate: String,
        shop: CatalogShop,
        settings: CatalogSettings,
        products: [CatalogProduct],
        districts: [CatalogDistrict],
        slots: [CatalogSlot]
    ) {
        self.serverDate = serverDate
        self.shop = shop
        self.settings = settings
        self.products = products
        self.districts = districts
        self.slots = slots
    }

    private enum CodingKeys: String, CodingKey {
        case serverDate = "server_date"
        case shop
        case settings
        case products
        case districts
        case slots
    }
}

public struct CatalogShop: Codable, Equatable, Sendable {
    public let name: String
    public let greeting: String
    /// E.164, for the `tel:` link.
    public let phoneContact: String
    /// Identifier for the `https://zalo.me/<contact>` link.
    public let zaloContact: String

    public init(name: String, greeting: String, phoneContact: String, zaloContact: String) {
        self.name = name
        self.greeting = greeting
        self.phoneContact = phoneContact
        self.zaloContact = zaloContact
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case greeting
        case phoneContact = "phone_contact"
        case zaloContact = "zalo_contact"
    }
}

/// Ordering parameters the apps validate against before calling the server.
public struct CatalogSettings: Codable, Equatable, Sendable {
    public let minQty: Int
    public let leadDays: Int
    public let maxDaysAhead: Int
    public let maxQtyPerCake: Int
    public let noteMaxLength: Int

    public init(minQty: Int, leadDays: Int, maxDaysAhead: Int, maxQtyPerCake: Int, noteMaxLength: Int) {
        self.minQty = minQty
        self.leadDays = leadDays
        self.maxDaysAhead = maxDaysAhead
        self.maxQtyPerCake = maxQtyPerCake
        self.noteMaxLength = noteMaxLength
    }

    private enum CodingKeys: String, CodingKey {
        case minQty = "min_qty"
        case leadDays = "lead_days"
        case maxDaysAhead = "max_days_ahead"
        case maxQtyPerCake = "max_qty_per_cake"
        case noteMaxLength = "note_max_length"
    }
}

/// `Product` of api.md section 3.
public struct CatalogProduct: Codable, Equatable, Sendable {
    public let productID: ResourceID
    public let slug: String
    public let name: String
    public let description: String
    public let priceVND: Int
    /// Absolute path on the API host (or a full URL when assets move).
    public let imageURL: String

    public init(productID: ResourceID, slug: String, name: String, description: String, priceVND: Int, imageURL: String) {
        self.productID = productID
        self.slug = slug
        self.name = name
        self.description = description
        self.priceVND = priceVND
        self.imageURL = imageURL
    }

    private enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case slug
        case name
        case description
        case priceVND = "price_vnd"
        case imageURL = "image_url"
    }
}

/// `District` of api.md section 3.
public struct CatalogDistrict: Codable, Equatable, Sendable {
    public let districtID: ResourceID
    public let name: String
    public let deliveryFeeVND: Int

    public init(districtID: ResourceID, name: String, deliveryFeeVND: Int) {
        self.districtID = districtID
        self.name = name
        self.deliveryFeeVND = deliveryFeeVND
    }

    private enum CodingKeys: String, CodingKey {
        case districtID = "district_id"
        case name
        case deliveryFeeVND = "delivery_fee_vnd"
    }
}

/// `Slot` of api.md section 3; times are `HH:MM` in shop time.
public struct CatalogSlot: Codable, Equatable, Sendable {
    public let slotID: ResourceID
    public let start: String
    public let end: String

    public init(slotID: ResourceID, start: String, end: String) {
        self.slotID = slotID
        self.start = start
        self.end = end
    }

    private enum CodingKeys: String, CodingKey {
        case slotID = "slot_id"
        case start
        case end
    }
}
