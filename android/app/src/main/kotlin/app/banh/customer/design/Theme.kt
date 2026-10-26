package app.banh.customer.design

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

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

// Stable MaterialTheme for the shell. The Expressive theme (opt-in API, ADR-0007) and the
// glass/blur fallback (ADR-0012) are added with the first real screens.
@Composable
fun BanhTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = BanhColorScheme, content = content)
}
