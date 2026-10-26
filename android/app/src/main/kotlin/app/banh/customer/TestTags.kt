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

    const val ORDER_STUB_STEP = "order.step"

    // Belongs to the full S-5 only; the slice 1 stub has no removed-cake message.
    const val ORDER_CAKE_REMOVED_NOTICE = "order.cakeRemovedNotice"

    /** Load failure of any screen, the zero-cake state, and the retry button both of them share. */
    const val ERROR_STATE = "state.error"
    const val EMPTY_STATE = "state.empty"
    const val STATE_RETRY = "state.retry"

    fun productCard(productId: String) = "products.card.$productId"
    fun productCardSkeleton(index: Int) = "products.skeleton.$index"
}
