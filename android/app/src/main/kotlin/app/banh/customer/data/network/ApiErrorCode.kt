package app.banh.customer.data.network

/** Stable error codes of docs/system/api.md section 5; the constant names are the wire values. */
enum class ApiErrorCode {
    VALIDATION_FAILED,
    MIN_QTY,
    DATE_LEAD,
    DATE_HORIZON,
    DATE_CAPACITY,
    DISTRICT_UNSERVED,
    PRICE_CHANGED,
    PRODUCT_UNAVAILABLE,
    SLOT_UNAVAILABLE,
    IDEMPOTENCY_KEY_REQUIRED,
    HEADER_INVALID,
    IDEMPOTENCY_KEY_REUSED,
    RATE_LIMITED,
    PAYLOAD_TOO_LARGE,
    ORDERING_PAUSED,
    SERVICE_UNAVAILABLE,
    INTERNAL_ERROR,
    NOT_FOUND,
    METHOD_NOT_ALLOWED,
    ;

    companion object {
        /** Unknown codes behave like `INTERNAL_ERROR` (api.md section 6). */
        fun fromWire(code: String): ApiErrorCode = entries.firstOrNull { it.name == code } ?: INTERNAL_ERROR
    }
}
