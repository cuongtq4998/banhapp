package app.banh.customer.design

// Raw ARGB values from docs/design/design-system.md section 2.1 (Android column).
// Kept as plain Long so unit tests can check contrast without the Android or Compose runtime.
object ColorTokens {
    const val PRIMARY = 0xFF1D6B3AL
    const val ON_PRIMARY = 0xFFFFFFFFL
    const val PRIMARY_CONTAINER = 0xFFC4EFCBL
    const val ON_PRIMARY_CONTAINER = 0xFF00210CL
    const val BACKGROUND_TOP = 0xFFF3F7EAL
    const val BACKGROUND_BOTTOM = 0xFFF8F1DDL
    const val SURFACE_SOLID = 0xFFFBF8EEL
    const val TEXT_PRIMARY = 0xFF1B2A1FL
    const val TEXT_SECONDARY = 0xFF4A5A4EL
    const val ERROR = 0xFFB3261EL
    const val ERROR_CONTAINER = 0xFFF9DEDCL
}
