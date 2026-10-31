package app.banh.customer.ui.order

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import app.banh.customer.R
import app.banh.customer.design.ColorTokens
import app.banh.customer.design.Spacing
import app.banh.customer.design.bodyStrong
import app.banh.customer.ui.common.formatMoney

/** Section title with the Edit control that opens the step where the section's data was entered (AC-18). */
@Composable
fun ReviewSectionHeader(title: String, editTestTag: String, onEdit: () -> Unit, enabled: Boolean = true) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(
            title,
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.weight(1f).semantics { heading() },
        )
        TextButton(onClick = onEdit, enabled = enabled, modifier = Modifier.testTag(editTestTag)) {
            Text(stringResource(R.string.common_edit), style = MaterialTheme.typography.labelLarge)
        }
    }
}

/** `SummaryRow` with a text value: label above value, so long addresses and large fonts wrap without squeezing. */
@Composable
fun TextSummaryRow(label: String, value: String, valueTestTag: String) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag(valueTestTag))
    }
}

/** `SummaryRow` with a money value: the label on the left, the amount on the right; [emphasized] for the total. */
@Composable
fun MoneySummaryRow(label: String, amountVnd: Long, valueTestTag: String, emphasized: Boolean = false, highlighted: Boolean = false) {
    val style = if (emphasized) MaterialTheme.typography.titleLarge else MaterialTheme.typography.bodyLarge
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Spacing.md), verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = style, modifier = Modifier.weight(1f))
        Text(formatMoney(amountVnd), style = style, textAlign = TextAlign.End, modifier = Modifier.highlight(highlighted).testTag(valueTestTag))
    }
}

/** One cake of the order: `name × quantity` and its line price (price times quantity, BR-5). */
@Composable
fun CakeSummaryRow(name: String, quantity: Int, lineTotalVnd: Long, rowTestTag: String, highlighted: Boolean = false) {
    Row(
        modifier = Modifier.fillMaxWidth().testTag(rowTestTag),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(stringResource(R.string.review_item, name, quantity), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Text(
            formatMoney(lineTotalVnd),
            style = MaterialTheme.typography.bodyStrong,
            textAlign = TextAlign.End,
            modifier = Modifier.highlight(highlighted).testTag("$rowTestTag.price"),
        )
    }
}

/** `color.warningContainer` behind an amount the server changed (UI document 5.8 c). */
private fun Modifier.highlight(on: Boolean): Modifier =
    if (on) background(Color(ColorTokens.WARNING_CONTAINER)) else this
