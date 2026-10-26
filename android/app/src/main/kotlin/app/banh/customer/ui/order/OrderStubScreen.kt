package app.banh.customer.ui.order

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.design.BanhScreen
import app.banh.customer.design.InlineTopBar
import app.banh.customer.design.Spacing

private const val FIRST_STEP = 1

/**
 * S-5 placeholder: the order flow opens here, empty, until the ordering slice fills it (architecture.md section 11).
 * Back leaves the flow and discards nothing, because no flow data exists yet.
 */
@Composable
fun OrderStubScreen(onBack: () -> Unit) {
    BanhScreen(topBar = { InlineTopBar(stringResource(R.string.flow_title), onBack) }) { innerPadding ->
        Column(Modifier.padding(innerPadding).padding(horizontal = Spacing.screenMargin)) {
            Text(stringResource(R.string.step_label, FIRST_STEP), style = MaterialTheme.typography.bodySmall, modifier = Modifier.testTag(TestTags.ORDER_STUB_STEP))
            Text(stringResource(R.string.step1), style = MaterialTheme.typography.titleLarge)
        }
    }
}
