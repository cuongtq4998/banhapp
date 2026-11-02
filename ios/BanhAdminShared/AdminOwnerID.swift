/// Identifiers of the owner screens S-A6 to S-A12 (docs/design/admin-orders/10 section 9.1) and of the
/// small extras this build adds (`.loading`, `.offline`, `.error`, `.retry`, `.message`, `.back`).
nonisolated enum AdminOwnerID {
    static let settingsRoot = "admin.settings.root"
    static let rowCakes = "admin.settings.row.cakes"
    static let rowRules = "admin.settings.row.rules"
    static let rowDelivery = "admin.settings.row.delivery"
    static let rowShop = "admin.settings.row.shop"
    static let rowStaff = "admin.settings.row.staff"
    static func rowValue(_ row: String) -> String { "\(row).value" }

    /// Shared by the owner screens (spec 9.2): load states and the inline save error.
    static let skeleton = "admin.owner.skeleton"
    static let offline = "admin.owner.offline"
    static let error = "admin.owner.error"
    static let retry = "admin.owner.retry"
    static let saveError = "admin.owner.saveError"
    static func back(_ screen: String) -> String { "admin.\(screen).back" }
    static func fieldError(_ screen: String, _ field: String) -> String { "admin.\(screen).error.\(field)" }
    static let districtErrorName = "admin.delivery.district.error.name"
    static let districtErrorFee = "admin.delivery.district.error.fee"

    static let cakes = "cakes"
    static let cakesAdd = "admin.cakes.add"
    static let cakesCount = "admin.cakes.count"
    static let cakesFull = "admin.cakes.full"
    static let cakesEmpty = "admin.cakes.empty"
    static func cakeRow(_ id: String) -> String { "admin.cakes.row.\(id)" }

    static let cakeForm = "cakeForm"
    static let cakeImage = "admin.cakeForm.image"
    static let cakeImageChange = "admin.cakeForm.change"
    static let cakeImagePreview = "admin.cakeForm.preview"
    static let cakeName = "admin.cakeForm.name"
    static let cakeDesc = "admin.cakeForm.desc"
    static let cakePrice = "admin.cakeForm.price"
    static let cakeActive = "admin.cakeForm.active"
    static let cakeSave = "admin.cakeForm.save"
    static let cakeProgress = "admin.cakeForm.progress"
    static let cakeCancel = "admin.cakeForm.cancel"
    static let cakeRemove = "admin.cakeForm.remove"
    static let cakeRemoveYes = "admin.cakeForm.removeYes"
    static let cakeGone = "admin.cakeForm.gone"
    static let cakeBackToList = "admin.cakeForm.backToList"

    static let rules = "rules"
    static let rulesLimit = "admin.rules.limit"
    static let rulesLead = "admin.rules.lead"
    static let rulesMin = "admin.rules.min"
    static let rulesSave = "admin.rules.save"
    static let rulesWarnDialog = "admin.rules.warnDialog"
    static let rulesWarnConfirm = "admin.rules.warnConfirm"
    static let rulesWarnBack = "admin.rules.warnBack"

    static let delivery = "delivery"
    static let districtAdd = "admin.delivery.district.add"
    static func districtRow(_ id: String) -> String { "admin.delivery.district.row.\(id)" }
    static func districtToggle(_ id: String) -> String { "admin.delivery.district.toggle.\(id)" }
    static let districtName = "admin.delivery.district.name"
    static let districtFee = "admin.delivery.district.fee"
    static let districtSave = "admin.delivery.district.save"
    static let districtError = "admin.delivery.district.error"
    static let slotAdd = "admin.delivery.slot.add"
    static func slotRow(_ id: String) -> String { "admin.delivery.slot.row.\(id)" }
    static func slotToggle(_ id: String) -> String { "admin.delivery.slot.toggle.\(id)" }
    static let slotStart = "admin.delivery.slot.start"
    static let slotEnd = "admin.delivery.slot.end"
    static let slotSave = "admin.delivery.slot.save"
    static let slotError = "admin.delivery.slot.error"

    static let shop = "shop"
    static let shopName = "admin.shop.name"
    static let shopGreeting = "admin.shop.greeting"
    static let shopPhone = "admin.shop.phone"
    static let shopZalo = "admin.shop.zalo"
    static let shopSave = "admin.shop.save"

    static let staff = "staff"
    static let staffAdd = "admin.staff.add"
    static let staffCount = "admin.staff.count"
    static let staffFull = "admin.staff.full"
    static func staffRow(_ id: String) -> String { "admin.staff.row.\(id)" }
    static let staffDeactivate = "admin.staff.deactivate"
    static let staffDeactivateYes = "admin.staff.deactivateYes"
    static let staffReactivate = "admin.staff.reactivate"
    static let staffAddName = "admin.staffAdd.name"
    static let staffAddEmail = "admin.staffAdd.email"
    static let staffAddSave = "admin.staffAdd.save"
    static let staffNone = "admin.staff.none"
    static let staffDetailMessage = "admin.staff.message"
    static let staffAddMessage = "admin.staffAdd.message"

    static let discardConfirm = "admin.discard.confirm"
    static let discardKeep = "admin.discard.keep"
    static let notifForeground = "admin.notif.foreground"
}

/// Debug launch argument that simulates a notification: `-BanhAdminPush tap:BT-9D6R3T` (as if the app
/// were opened from the notification) or `foreground:BT-9D6R3T` (arrives 2 s after launch).
nonisolated enum AdminPushLaunch {
    static let key = "BanhAdminPush"
}
