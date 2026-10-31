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
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign

/**
 * Full-area message: icon, message and a retry button (`StateView` Error). Text, icon and test tags come from the
 * caller (ADR-0018: design imports neither the resource class nor the test tags); `ui.common` binds them.
 * The caller picks [stateTag] so a test can tell "the shop has nothing to sell" from "the data could not be loaded".
 */
@Composable
fun StateMessage(
    message: String,
    retryLabel: String,
    icon: Painter,
    stateTag: String,
    retryTag: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(Spacing.lg)
            .testTag(stateTag),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Icon(
            painter = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.error,
        )
        Text(message, style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
        SecondaryButton(
            text = retryLabel,
            onClick = onRetry,
            modifier = Modifier.testTag(retryTag),
        )
    }
}

/** Information next to the content it explains (`InlineMessage`, Info); the tag goes on the whole message. */
@Composable
fun InfoMessageView(text: String, icon: Painter, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(Radii.image))
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(painter = icon, contentDescription = null, tint = MaterialTheme.colorScheme.onPrimaryContainer)
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
fun Modifier.loadingSemanticsLabeled(label: String): Modifier {
    return semantics(mergeDescendants = true) { contentDescription = label }
}
