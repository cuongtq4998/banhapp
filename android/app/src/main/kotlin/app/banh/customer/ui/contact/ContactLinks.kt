package app.banh.customer.ui.contact

import okhttp3.HttpUrl

private const val ZALO_HOST = "zalo.me"
private const val ZALO_SCHEME = "https"
private const val PHONE_SCHEME_PREFIX = "tel:"

/** Link forms of ADR-0015: a web link for Zalo (no custom scheme) and `tel:` for the dialer. */
object ContactLinks {
    fun zaloUrl(zaloContact: String): String =
        HttpUrl.Builder().scheme(ZALO_SCHEME).host(ZALO_HOST).addPathSegment(zaloContact).build().toString()

    fun phoneUri(phoneContact: String): String = PHONE_SCHEME_PREFIX + phoneContact
}
