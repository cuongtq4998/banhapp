package app.banh.core.design

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/** Container for grouped content: translucent over the blurred background, opaque where blur is unavailable. */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(Radii.card)
    val glass = LocalSurfaceStyle.current == SurfaceStyle.GLASS
    val container = if (glass) {
        Color(ColorTokens.SURFACE_GLASS).copy(alpha = AlphaTokens.GLASS_SURFACE)
    } else {
        Color(ColorTokens.SURFACE_SOLID).copy(alpha = AlphaTokens.SOLID_FALLBACK)
    }
    val border = BorderStroke(Sizes.hairline, Color(ColorTokens.SURFACE_STROKE).copy(alpha = if (glass) AlphaTokens.STROKE else AlphaTokens.SOLID_FALLBACK))
    val body: @Composable () -> Unit = { Column(modifier = Modifier.padding(Spacing.lg), content = content) }
    // The container colour is not a theme colour, so the text colour is stated instead of derived.
    val contentColor = MaterialTheme.colorScheme.onSurface
    if (onClick == null) {
        Surface(
            modifier = modifier,
            shape = shape,
            color = container,
            contentColor = contentColor,
            // No elevation shadow: under a translucent colour it shows through as a lighter rectangle that ignores the rounded corners.
            shadowElevation = 0.dp,
            border = border,
            content = body,
        )
    } else {
        Surface(
            onClick = onClick,
            modifier = modifier,
            shape = shape,
            color = container,
            contentColor = contentColor,
            // No elevation shadow: under a translucent colour it shows through as a lighter rectangle that ignores the rounded corners.
            shadowElevation = 0.dp,
            border = border,
            content = body,
        )
    }
}
