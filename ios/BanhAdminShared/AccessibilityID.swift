/// Accessibility identifiers, the selectors of the UI tests: one list the app and the UI test target
/// both compile (docs/design/admin-orders/10-accessibility-test-ids.md section 9.1). Values are
/// identical to the Android test tags.
nonisolated enum AdminID {
    static let signInEmail = "admin.signin.email"
    static let signInSend = "admin.signin.send"
    static let signInError = "admin.signin.error"
    static let signInBanner = "admin.signin.banner"
    static let codeField = "admin.code.field"
    static let codeSubmit = "admin.code.submit"
    static let codeResend = "admin.code.resend"
    static let codeChangeEmail = "admin.code.changeEmail"
    static let codeError = "admin.code.error"

    static let ordersTitle = "admin.orders.title"
    static let ordersSearch = "admin.orders.search"
    static let ordersAccount = "admin.orders.accountButton"
    static let ordersBadge = "admin.orders.badge"
    static let filterTodo = "admin.orders.filter.todo"
    static let filterReceived = "admin.orders.filter.received"
    static let filterProcessing = "admin.orders.filter.processing"
    static let filterScheduled = "admin.orders.filter.scheduled"
    static let filterDelivering = "admin.orders.filter.delivering"
    static let filterFinished = "admin.orders.filter.finished"
    static let filterCancelled = "admin.orders.filter.cancelled"
    static let filterAll = "admin.orders.filter.all"
    static let filterDate = "admin.orders.filter.date"
    static let dateAll = "admin.orders.date.all"
    static let dateToday = "admin.orders.date.today"
    static let dateTomorrow = "admin.orders.date.tomorrow"
    static let dateOne = "admin.orders.date.one"
    static let dateOk = "admin.orders.date.ok"
    static let dateCancel = "admin.orders.date.cancel"
    static let ordersList = "admin.orders.list"
    static let ordersSkeleton = "admin.orders.skeleton"
    static let ordersEmpty = "admin.orders.empty"
    static let ordersError = "admin.orders.error"
    static let ordersOffline = "admin.orders.offline"
    static let ordersLoadMoreError = "admin.orders.loadMoreError"
    static let ordersSearchMin = "admin.orders.searchMin"
    static let ordersClearFilters = "admin.orders.clearFilters"
    static let ordersRetry = "admin.orders.retry"
    static func row(_ code: String) -> String { "admin.orders.row.\(code)" }
    static func due(_ code: String) -> String { "admin.orders.due.\(code)" }
    static let tabOrders = "admin.tab.orders"
    static let tabSettings = "admin.tab.settings"

    static let detailCode = "admin.detail.code"
    static let detailStatus = "admin.detail.status"
    static let detailDue = "admin.detail.due"
    static let detailCustomer = "admin.detail.customer"
    static let detailPhone = "admin.detail.phone"
    static let detailCall = "admin.detail.call"
    static let detailZalo = "admin.detail.zalo"
    static let detailAddress = "admin.detail.address"
    static let detailDelivery = "admin.detail.delivery"
    static let detailCakes = "admin.detail.cakes"
    static func detailCake(_ index: Int) -> String { "admin.detail.cake.\(index)" }
    static let detailFee = "admin.detail.fee"
    static let detailTotal = "admin.detail.total"
    static let detailNote = "admin.detail.note"
    static let detailReason = "admin.detail.reason"
    static let detailLastChanged = "admin.detail.lastChanged"
    static let detailConfirm = "admin.detail.confirm"
    static let detailComplete = "admin.detail.complete"
    static let detailCancel = "admin.detail.cancel"
    static let detailCompleteYes = "admin.detail.completeYes"
    static let detailCompleteBack = "admin.detail.completeBack"
    static let detailConflict = "admin.detail.conflict"
    static let detailError = "admin.detail.error"
    static let detailGone = "admin.detail.gone"
    static let detailRetry = "admin.detail.retry"
    static let detailSkeleton = "admin.detail.skeleton"

    static let cancelCustomer = "admin.cancel.reason.customer"
    static let cancelCannotDeliver = "admin.cancel.reason.cannotDeliver"
    static let cancelNoContact = "admin.cancel.reason.noContact"
    static let cancelSpam = "admin.cancel.reason.spam"
    static let cancelConfirm = "admin.cancel.confirm"
    static let cancelBack = "admin.cancel.back"
    static let cancelError = "admin.cancel.error"

    static let settingsSignOutOthers = "admin.settings.signOutOthers"
    static let settingsSignOutOthersYes = "admin.settings.signOutOthersYes"
    static let settingsSignOut = "admin.settings.signOut"
    static let settingsSignOutYes = "admin.settings.signOutYes"
    static let accountName = "admin.account.name"
    static let accountEmail = "admin.account.email"
    static let accountSignOutOthers = "admin.account.signOutOthers"
    static let accountSignOutOthersYes = "admin.account.signOutOthersYes"
    static let accountSignOut = "admin.account.signOut"
    static let accountSignOutYes = "admin.account.signOutYes"

    static let toast = "admin.toast"
    static let navBack = "admin.nav.back"
}

/// Launch arguments of the debug stub backend: `-BanhAdminStub <mode>` (UserDefaults argument syntax).
nonisolated enum AdminLaunch {
    static let stub = "BanhAdminStub"
    /// Signed out, staff account behind the code `123456`.
    static let modeSignIn = "signin"
    /// Signed out, an e-mail starting with "owner" gets an owner account.
    static let modeSignInOwner = "signinOwner"
    static let modeStaff = "staff"
    static let modeOwner = "owner"
    /// Status requests answer 409: somebody else confirmed the order first.
    static let modeConflict = "conflict"
    /// The access token has expired: the first request is refused, the refresh works.
    static let modeRefresh = "refresh"
    /// Every admin request answers 401 `SESSION_REVOKED`.
    static let modeRevoked = "revoked"
    static let modeOffline = "offline"
    static let modeEmpty = "empty"
    static let modeGone = "gone"
    static let modeServerError = "serverError"
    /// Owner modes: `ownerFull` has 12 cakes and 30 active staff, `ownerOffline` and `ownerError` fail every
    /// owner call (no connection, 500), `ownerSlow` makes the cake upload take 30 s (cancel test).
    static let modeOwnerFull = "ownerFull"
    static let modeOwnerOffline = "ownerOffline"
    static let modeOwnerError = "ownerError"
    static let modeOwnerSlow = "ownerSlow"
    static let ownerModes: Set<String> = [modeOwner, modeSignInOwner, modeOwnerFull, modeOwnerOffline, modeOwnerError, modeOwnerSlow]
    static let fakeCode = "123456"
    static let fakeEmail = "nhanvien.a@example.com"
}
