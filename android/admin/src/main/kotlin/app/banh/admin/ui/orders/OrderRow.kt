package app.banh.admin.ui.orders

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.banh.admin.R
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.text
import app.banh.admin.ui.textRes
import app.banh.admin.ui.tone
import app.banh.core.common.dueMarkOf
import app.banh.core.common.formatDate
import app.banh.core.common.formatVnd
import app.banh.core.design.DueMarkChip
import app.banh.core.design.GlassCard
import app.banh.core.design.SkeletonBlock
import app.banh.core.design.Spacing
import app.banh.core.design.StatusBadge
import app.banh.core.model.OrderSummary

/**
 * `OrderRow` (FR-9): code, status, customer, delivery date and slot with the due mark, cakes, total, district. No phone, address
 * or note. The mark uses the server date of the same answer, never the device clock (TQ-D8).
 */
@Composable
fun OrderRow(order: OrderSummary, serverDate: String?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val hint = stringResource(R.string.a_row_hint_a11y)
    val due = serverDate?.let { dueMarkOf(order.status, order.deliveryDate, it) }
    GlassCard(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().testTag(AdminTags.orderRow(order.orderCode)).semantics(mergeDescendants = true) { onClick(label = hint) { false } },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            Text(order.orderCode, fontSize = 15.sp, fontWeight = FontWeight.Bold)
            StatusBadge(stringResource(order.status.textRes()), order.status.tone())
        }
        Text(order.customerName, style = MaterialTheme.typography.titleMedium)
        // The mark moves under the date when the line is too narrow (large text).
        FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalArrangement = Arrangement.spacedBy(Spacing.xs), itemVerticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.a_row_delivery, formatDate(order.deliveryDate, serverDate), "${order.slot.start} – ${order.slot.end}"), style = MaterialTheme.typography.bodyMedium)
            if (due != null) DueMarkChip(due.text(context), painterResource(R.drawable.ic_clock), Modifier.testTag(AdminTags.orderDue(order.orderCode)))
        }
        Text(
            stringResource(R.string.a_row_meta, order.totalCakes, formatVnd(order.totalVnd), order.districtName),
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
        )
    }
}

/** Five placeholder rows while the first page loads (S-A3 Loading). */
@Composable
fun OrderRowSkeletons(modifier: Modifier = Modifier) {
    Column(modifier = modifier.testTag(AdminTags.ORDERS_SKELETON), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
        repeat(SKELETON_ROWS) { SkeletonBlock(Modifier.fillMaxWidth().height(112.dp)) }
    }
}

private const val SKELETON_ROWS = 5
