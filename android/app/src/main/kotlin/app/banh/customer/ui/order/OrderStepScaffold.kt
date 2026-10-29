package app.banh.customer.ui.order

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.design.BanhScreen
import app.banh.customer.design.BottomActionBar
import app.banh.customer.design.InlineTopBar
import app.banh.customer.design.Spacing

@StringRes
private fun stepTitle(step: Int): Int = when (step) {
    1 -> R.string.step1
    2 -> R.string.step2
    3 -> R.string.step3
    else -> R.string.step4
}

/**
 * Frame of S-5 to S-8: top bar with back, the step label and title, scrolling content, and the bottom bar. The
 * content area gets the padding that keeps it clear of both bars, so the bar never covers the last field (UI document 9).
 */
@Composable
fun OrderStepScaffold(
    step: Int,
    onBack: () -> Unit,
    bottomBar: @Composable ColumnScope.() -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    BanhScreen(
        topBar = { InlineTopBar(stringResource(R.string.flow_title), onBack) },
        bottomBar = { BottomActionBar(content = bottomBar) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.screenMargin),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            Column {
                Text(
                    stringResource(R.string.step_label, step),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.testTag(TestTags.ORDER_STEP),
                )
                Text(
                    stringResource(stepTitle(step)),
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.semantics { heading() },
                )
            }
            content()
        }
    }
}
