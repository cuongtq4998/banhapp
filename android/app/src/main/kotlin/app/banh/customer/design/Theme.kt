package app.banh.customer.design

import android.os.Build
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.intl.LocaleList

private const val VIETNAMESE_LANGUAGE_TAG = "vi"

private val BanhColorScheme = lightColorScheme(
    primary = Color(ColorTokens.PRIMARY),
    onPrimary = Color(ColorTokens.ON_PRIMARY),
    primaryContainer = Color(ColorTokens.PRIMARY_CONTAINER),
    onPrimaryContainer = Color(ColorTokens.ON_PRIMARY_CONTAINER),
    background = Color(ColorTokens.BACKGROUND_BOTTOM),
    onBackground = Color(ColorTokens.TEXT_PRIMARY),
    surface = Color(ColorTokens.SURFACE_SOLID),
    onSurface = Color(ColorTokens.TEXT_PRIMARY),
    onSurfaceVariant = Color(ColorTokens.TEXT_SECONDARY),
    error = Color(ColorTokens.ERROR),
    errorContainer = Color(ColorTokens.ERROR_CONTAINER),
)

// design-system.md section 2.2: the Material 3 scale in sp, with the emphasised weights of the token table.
private val BanhTypography = Typography().let {
    it.copy(
        headlineLarge = it.headlineLarge.copy(fontWeight = FontWeight.Bold),
        headlineMedium = it.headlineMedium.copy(fontWeight = FontWeight.Bold),
        titleLarge = it.titleLarge.copy(fontWeight = FontWeight.Medium),
    )
}

/** `type.body.strong`: prices and totals. */
val Typography.bodyStrong: TextStyle get() = bodyLarge.copy(fontWeight = FontWeight.Medium)

// The Expressive theme (opt-in API, ADR-0007) is not used yet: its names could not be checked against a
// build. The surface style (ADR-0012) and motion preference travel through composition locals.
@Composable
fun BanhTheme(content: @Composable () -> Unit) {
    val preferences = rememberAccessibilityPreferences()
    val surfaceStyle = surfaceStyleFor(Build.VERSION.SDK_INT, preferences.highContrast)
    CompositionLocalProvider(
        LocalSurfaceStyle provides surfaceStyle,
        LocalReduceMotion provides preferences.reduceMotion,
    ) {
        MaterialTheme(colorScheme = BanhColorScheme, typography = BanhTypography) {
            // Marks all text as Vietnamese so the screen reader speaks it with the right voice (UI document 9).
            CompositionLocalProvider(
                LocalTextStyle provides LocalTextStyle.current.merge(TextStyle(localeList = LocaleList(VIETNAMESE_LANGUAGE_TAG))),
                content = content,
            )
        }
    }
}
