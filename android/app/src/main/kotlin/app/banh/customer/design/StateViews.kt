package app.banh.customer.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import app.banh.customer.TestTags
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.banh.customer.R

/** Full-area error: icon, message and a retry button (`StateView` Error). */
@Composable
fun ErrorState(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(Spacing.lg)
            .testTag(TestTags.ERROR_STATE),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_error),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.error,
        )
        Text(message, style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
        SecondaryButton(
            text = stringResource(R.string.common_retry),
            onClick = onRetry,
            modifier = Modifier.testTag(TestTags.ERROR_RETRY),
        )
    }
}

/** Grey placeholder block shown while data loads (`StateView` Loading, skeleton form). */
@Composable
fun SkeletonBlock(modifier: Modifier = Modifier, shape: RoundedCornerShape = RoundedCornerShape(Spacing.sm)) {
    Box(
        modifier = modifier.background(
            Color(ColorTokens.TEXT_PRIMARY).copy(alpha = AlphaTokens.DISABLED_FILL),
            shape,
        ),
    )
}

/** Marks a group of skeleton blocks as one "loading" element for the screen reader. */
@Composable
fun Modifier.loadingSemantics(): Modifier {
    val label = stringResource(R.string.common_loading)
    return semantics(mergeDescendants = true) { contentDescription = label }
}
