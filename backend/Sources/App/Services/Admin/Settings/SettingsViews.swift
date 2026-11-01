import Vapor

// Response bodies of api/07 sections 10.13 to 10.18 (snake_case).

struct ShopSection: Content, Equatable {
    let name: String
    let greeting: String
    let phoneContact: String
    let zaloContact: String

    enum CodingKeys: String, CodingKey {
        case name, greeting, phoneContact = "phone_contact", zaloContact = "zalo_contact"
    }
}

struct OrderingSection: Content, Equatable {
    let dailyLimit: Int
    let leadDays: Int
    let minQty: Int
    let maxDaysAhead: Int

    enum CodingKeys: String, CodingKey {
        case dailyLimit = "daily_limit", leadDays = "lead_days", minQty = "min_qty", maxDaysAhead = "max_days_ahead"
    }
}

/// A date that already holds more cakes than a limit (data-model/05 section 13).
struct OverLimitDate: Content, Equatable {
    let date: String
    let cakesAccepted: Int

    enum CodingKeys: String, CodingKey { case date, cakesAccepted = "cakes_accepted" }
}

/// `GET .../ordering/impact` (the preview).
struct OrderingImpact: Content, Equatable {
    let dailyLimit: Int
    let overLimit: [OverLimitDate]
    let count: Int

    enum CodingKeys: String, CodingKey { case dailyLimit = "daily_limit", overLimit = "over_limit", count }
}

/// `PUT .../ordering`: the section as saved, plus the list true at save time.
struct OrderingSaved: Content, Equatable {
    let dailyLimit: Int
    let leadDays: Int
    let minQty: Int
    let maxDaysAhead: Int
    let overLimit: [OverLimitDate]
    let count: Int

    enum CodingKeys: String, CodingKey {
        case dailyLimit = "daily_limit", leadDays = "lead_days", minQty = "min_qty", maxDaysAhead = "max_days_ahead"
        case overLimit = "over_limit", count
    }
}

struct CakeView: Content, Equatable {
    let cakeID: UUID
    let name: String
    let description: String
    let priceVND: Int
    let isActive: Bool
    let imageURL: String

    enum CodingKeys: String, CodingKey {
        case cakeID = "cake_id", name, description, priceVND = "price_vnd", isActive = "is_active", imageURL = "image_url"
    }
}

struct DistrictView: Content, Equatable {
    let districtID: UUID
    let name: String
    let deliveryFeeVND: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case districtID = "district_id", name, deliveryFeeVND = "delivery_fee_vnd", isActive = "is_active"
    }
}

struct SlotView: Content, Equatable {
    let slotID: UUID
    let start: String
    let end: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey { case slotID = "slot_id", start, end, isActive = "is_active" }
}

struct SettingsResponse: Content {
    let shop: ShopSection
    let ordering: OrderingSection
    let cakes: [CakeView]
    let districts: [DistrictView]
    let slots: [SlotView]
    let cakeCountMax: Int
    let staffCountMax: Int

    enum CodingKeys: String, CodingKey {
        case shop, ordering, cakes, districts, slots, cakeCountMax = "cake_count_max", staffCountMax = "staff_count_max"
    }
}

struct StaffView: Content, Equatable {
    let accountID: UUID
    let name: String
    let email: String
    let role: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id", name, email, role, isActive = "is_active"
    }
}

struct StaffList: Content {
    let accounts: [StaffView]
}
