package app.banh.customer.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

private val GreenBlobSize = 280.dp
private val CreamBlobSize = 320.dp
private val BlobBlurRadius = 64.dp

/** Vertical soft gradient with two colour blobs; the blobs are blurred where the system can blur (ADR-0012). */
@Composable
fun AppBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .clipToBounds()
            .background(Brush.verticalGradient(listOf(Color(ColorTokens.BACKGROUND_TOP), Color(ColorTokens.BACKGROUND_BOTTOM)))),
    ) {
        Blob(Color(ColorTokens.BLOB_GREEN), GreenBlobSize, Alignment.TopEnd, x = 72.dp, y = (-48).dp)
        Blob(Color(ColorTokens.BLOB_CREAM), CreamBlobSize, Alignment.BottomStart, x = (-96).dp, y = 72.dp)
        content()
    }
}

@Composable
private fun BoxScope.Blob(color: Color, size: Dp, alignment: Alignment, x: Dp, y: Dp) {
    val tinted = color.copy(alpha = AlphaTokens.BLOB)
    val shape = Modifier.align(alignment).offset(x, y).size(size)
    val blob = when (LocalSurfaceStyle.current) {
        SurfaceStyle.GLASS -> shape.blur(BlobBlurRadius, BlurredEdgeTreatment.Unbounded).background(tinted, CircleShape)
        // No blur available: a radial fade gives the same soft edge as a flat gradient.
        SurfaceStyle.OPAQUE -> shape.background(Brush.radialGradient(listOf(tinted, Color.Transparent)), CircleShape)
    }
    Box(blob)
}
