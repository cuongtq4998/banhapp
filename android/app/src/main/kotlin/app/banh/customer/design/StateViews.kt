package app.banh.customer.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
    StateMessage(message, onRetry, TestTags.ERROR_STATE, modifier)
}

/**
 * Zero cakes to show: the Error layout with its own tag, so a test (and the reader of the code) can tell
 * "the shop has nothing to sell" from "the data could not be loaded" (BR-13).
 */
@Composable
fun EmptyState(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    StateMessage(message, onRetry, TestTags.EMPTY_STATE, modifier)
}

@Composable
private fun StateMessage(message: String, onRetry: () -> Unit, stateTag: String, modifier: Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(Spacing.lg)
            .testTag(stateTag),
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
            modifier = Modifier.testTag(TestTags.STATE_RETRY),
        )
    }
}

/** Information next to the content it explains (`InlineMessage`, Info); the tag goes on the whole message. */
@Composable
fun InfoMessage(text: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(Radii.image))
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(painter = painterResource(R.drawable.ic_info), contentDescription = null, tint = MaterialTheme.colorScheme.onPrimaryContainer)
        Text(text, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onPrimaryContainer)
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
