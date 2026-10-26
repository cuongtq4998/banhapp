package app.banh.customer.design

import androidx.compose.ui.unit.dp

// Spacing, size and radius tokens (design-system.md sections 2.3 and 2.4, Android column).
object Spacing {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 24.dp
    val xxl = 32.dp
    val screenMargin = 20.dp
}

object Sizes {
    val touchTarget = 48.dp
    val buttonHeight = 56.dp
    val thumb = 72.dp
    val hairline = 1.dp
    val cardShadow = 2.dp

    // The UI document names a large and a small logo without numbers; these are proposed values.
    val logoLarge = 128.dp
    val logoSmall = 56.dp
}

object Radii {
    val card = 28.dp
    val image = 20.dp
}

// Durations of design-system.md section 2.6.
object Motion {
    const val SHORT_MILLIS = 150
    const val MEDIUM_MILLIS = 250
    const val LONG_MILLIS = 400
}
