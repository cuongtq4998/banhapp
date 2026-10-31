package app.banh.customer

/**
 * Selectors for Compose UI tests (`onNodeWithTag`). Kept in one object so they can follow the list
 * canvas-ui publishes with a single edit.
 */
object TestTags {
    const val LAUNCH_LOGO = "launch.logo"

    const val HOME_SHOP_NAME = "home.shopName"
    const val HOME_GREETING = "home.greeting"
    const val HOME_ZALO = "home.zaloButton"
    const val HOME_PHONE = "home.phoneButton"
    const val HOME_PRODUCTS = "home.productsButton"
    const val HOME_ORDER = "home.orderButton"
    const val HOME_SKELETON = "home.skeleton"
    const val HOME_NO_CAKES_NOTICE = "home.noCakesNotice"

    const val PRODUCTS_LIST = "products.list"

    const val DETAIL_NAME = "detail.name"
    const val DETAIL_DESCRIPTION = "detail.description"
    const val DETAIL_PRICE = "detail.price"
    const val DETAIL_ORDER = "detail.orderButton"
    const val DETAIL_IMAGE_FAILED = "detail.imageFailed"
    const val DETAIL_GONE_NOTICE = "detail.goneNotice"
    const val DETAIL_GONE_ACTION = "detail.goneAction"

    /** Round glass back button of the custom header, the same on every screen that has one (UI document 9.1). */
    const val NAV_BACK = "nav.back"

    // Order flow, S-5 to S-8. The identifiers below are proposed by forge-dev for slice 2; the canonical set is
    // docs/design/place-order-ui/09-accessibility-test-ids.md section 9.1 (deviations: 09b).
    const val ORDER_TITLE = "order.title"
    const val ORDER_STEP = "order.step"
    const val ORDER_NEXT = "order.next"
    const val ORDER_CAKE_REMOVED_NOTICE = "order.cakeRemovedNotice"
    const val ORDER_QTY_TOTAL = "order.qty.total"
    const val ORDER_QTY_SUBTOTAL = "order.qty.subtotal"
    const val ORDER_QTY_MIN_HINT = "order.qty.minHint"

    const val ORDER_DATE_MONTH = "order.date.month"
    const val ORDER_DATE_PREVIOUS = "order.date.previous"
    const val ORDER_DATE_NEXT = "order.date.next"
    const val ORDER_DATE_EMPTY = "order.date.empty"
    const val ORDER_DATE_EMPTY_ACTION = "order.date.emptyAction"
    const val ORDER_DATE_CLEARED = "order.date.cleared"
    const val ORDER_DATE_RANGE_HINT = "order.date.rangeHint"
    const val ORDER_DATE_HINT = "order.date.hint"
    const val ORDER_DATE_LOADING = "order.date.loading"

    const val ORDER_FIELD_NAME = "order.field.name"
    const val ORDER_FIELD_PHONE = "order.field.phone"
    const val ORDER_FIELD_ADDRESS = "order.field.address"
    const val ORDER_FIELD_DISTRICT = "order.field.district"
    const val ORDER_FIELD_NOTE = "order.field.note"
    const val ORDER_NOTE_COUNTER = "order.note.counter"
    const val ORDER_NOTE_ERROR = "order.error.note"
    const val ORDER_DISTRICT_FEE = "order.district.fee"
    const val ORDER_DISTRICT_ERROR = "order.district.error"
    const val ORDER_DISTRICT_EMPTY = "order.district.empty"

    const val ORDER_PRIVACY_CARD = "order.privacy.card"
    const val ORDER_PRIVACY_TITLE = "order.privacy.title"
    const val ORDER_PRIVACY_BODY = "order.privacy.body"
    const val ORDER_PRIVACY_DRAFT = "order.privacy.draft"
    const val ORDER_PRIVACY_LINK = "order.privacy.link"

    const val REVIEW_TOTAL = "review.total"
    const val REVIEW_FEE = "review.fee"
    const val REVIEW_DATE = "review.date"
    const val REVIEW_TIME = "review.time"
    const val REVIEW_NAME = "review.name"
    const val REVIEW_PHONE = "review.phone"
    const val REVIEW_ADDRESS = "review.address"
    const val REVIEW_NOTE = "review.note"
    const val REVIEW_PRIVACY = "review.privacy"
    const val REVIEW_PRIVACY_LINK = "review.privacy.link"
    const val REVIEW_CONFIRM = "review.confirm"
    const val REVIEW_EDIT_CAKES = "review.edit.cakes"
    const val REVIEW_EDIT_DELIVERY = "review.edit.date"
    const val REVIEW_EDIT_RECIPIENT = "review.edit.recipient"
    const val REVIEW_ISSUE = "review.message"
    const val REVIEW_MESSAGE_ACTION = "review.messageAction"

    // S-8 send states and S-9; the S-9 identifiers are proposed by forge-dev (09-accessibility-test-ids.md has none yet).
    const val REVIEW_PRICE_CHANGED = "review.priceChanged"
    const val REVIEW_SENDING = "review.sending"
    const val CONF_TITLE = "conf.title"
    const val CONF_CODE = "conf.code"
    const val CONF_MESSAGE = "conf.message"
    const val CONF_ZALO = "conf.zalo"
    const val CONF_PHONE = "conf.phone"
    const val CONF_HOME = "conf.home"

    /** Load failure of any screen, the zero-cake state, and the retry button both of them share. */
    const val ERROR_STATE = "state.error"
    const val EMPTY_STATE = "state.empty"
    const val STATE_TOAST = "state.toast"
    const val STATE_RETRY = "state.retry"

    fun productCard(productId: String) = "products.card.$productId"
    fun productCardSkeleton(index: Int) = "products.skeleton.$index"

    fun orderQtyValue(productId: String) = "order.qty.$productId.value"
    fun orderQtyIncrease(productId: String) = "order.qty.$productId.inc"
    fun orderQtyDecrease(productId: String) = "order.qty.$productId.dec"

    /** A day of the calendar; [isoDate] is `yyyy-MM-dd`. */
    fun orderDate(isoDate: String) = "order.date.$isoDate"
    fun orderSlot(slotId: String) = "order.slot.$slotId"
    fun orderFieldError(field: String) = "order.error.$field"
    fun orderDistrictRow(districtId: String) = "order.district.row.$districtId"

    fun reviewItem(productId: String) = "review.item.$productId"
    fun reviewItemPrice(productId: String) = "review.item.$productId.price"
}
