package app.banh.customer.ui.common

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.TopAppBarScrollBehavior
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.design.BackControl
import app.banh.customer.design.BanhInlineTopBar
import app.banh.customer.design.BanhLargeTitleTopBar
import app.banh.customer.design.ErrorMessageView
import app.banh.customer.design.InfoMessageView
import app.banh.customer.design.LogoBlob
import app.banh.customer.design.StateMessage
import app.banh.customer.design.loadingSemanticsLabeled

/*
 * ADR-0018: the design package imports neither the generated resource class nor the test tags. These functions give
 * the design components their strings, icons and tags, so screens keep one short call.
 */

/** Full-area error: icon, message and a retry button. */
@Composable
fun ErrorState(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    StateMessage(
        message = message,
        retryLabel = stringResource(R.string.common_retry),
        icon = painterResource(R.drawable.ic_error),
        stateTag = TestTags.ERROR_STATE,
        retryTag = TestTags.STATE_RETRY,
        onRetry = onRetry,
        modifier = modifier,
    )
}

/** Zero cakes to show: the Error layout with its own tag, so "nothing to sell" differs from "could not load" (BR-13). */
@Composable
fun EmptyState(message: String, onRetry: () -> Unit, modifier: Modifier = Modifier) {
    StateMessage(
        message = message,
        retryLabel = stringResource(R.string.common_retry),
        icon = painterResource(R.drawable.ic_error),
        stateTag = TestTags.EMPTY_STATE,
        retryTag = TestTags.STATE_RETRY,
        onRetry = onRetry,
        modifier = modifier,
    )
}

@Composable
fun InfoMessage(text: String, modifier: Modifier = Modifier) {
    InfoMessageView(text, painterResource(R.drawable.ic_info), modifier)
}

@Composable
fun ErrorMessage(
    text: String,
    modifier: Modifier = Modifier,
    actionLabel: String? = null,
    actionTestTag: String? = null,
    onAction: () -> Unit = {},
) {
    ErrorMessageView(text, painterResource(R.drawable.ic_error), modifier, actionLabel, actionTestTag, onAction)
}

@Composable
fun Modifier.loadingSemantics(): Modifier = loadingSemanticsLabeled(stringResource(R.string.common_loading))

@Composable
fun LogoMark(size: Dp, modifier: Modifier = Modifier) {
    LogoBlob(size, stringResource(R.string.logo_label), modifier)
}

@Composable
private fun backControl() = BackControl(
    icon = painterResource(R.drawable.ic_arrow_back),
    label = stringResource(R.string.common_back),
    testTag = TestTags.NAV_BACK,
)

@Composable
fun InlineTopBar(title: String, onBack: () -> Unit) {
    BanhInlineTopBar(title, backControl(), onBack)
}

@ExperimentalMaterial3Api
@Composable
fun LargeTitleTopBar(title: String, onBack: () -> Unit, scrollBehavior: TopAppBarScrollBehavior? = null) {
    BanhLargeTitleTopBar(title, backControl(), onBack, scrollBehavior)
}
