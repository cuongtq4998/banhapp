package app.banh.customer.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import app.banh.customer.R

private const val BLOB_LARGE_CORNER_PERCENT = 50
private const val BLOB_SMALL_CORNER_PERCENT = 36
private const val INNER_BLOB_INSET_DIVISOR = 4

// Organic blob (`radius.logo` on Android): corners of unequal roundness.
private val BlobShape = RoundedCornerShape(
    topStartPercent = BLOB_LARGE_CORNER_PERCENT,
    topEndPercent = BLOB_SMALL_CORNER_PERCENT,
    bottomEndPercent = BLOB_LARGE_CORNER_PERCENT,
    bottomStartPercent = BLOB_SMALL_CORNER_PERCENT,
)

/**
 * Shop logo. No logo file exists yet (the catalog carries none), so this draws a neutral placeholder
 * mark; the real artwork replaces the body of this function only.
 */
@Composable
fun LogoMark(size: Dp, modifier: Modifier = Modifier) {
    val label = stringResource(R.string.logo_label)
    Box(
        modifier = modifier
            .size(size)
            .background(Color(ColorTokens.PRIMARY), BlobShape)
            .semantics { contentDescription = label },
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .padding(size / INNER_BLOB_INSET_DIVISOR)
                .background(Color(ColorTokens.PRIMARY_CONTAINER), BlobShape),
        )
    }
}
