package app.banh.admin.ui.detail

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import app.banh.admin.R
import app.banh.admin.orderdetail.deliveryLinesOf
import app.banh.admin.ui.AdminOrderTags
import app.banh.admin.ui.text
import app.banh.core.common.dueMarkOf
import app.banh.core.common.formatWeekdayDate
import app.banh.core.design.DueMarkChip
import app.banh.core.design.GlassCard
import app.banh.core.design.Sizes
import app.banh.core.design.Spacing
import app.banh.core.model.OrderDetail

/** What the customer asked, what staff set (tap opens the date sheet when allowed), the red mark when due, address and district. */
@Composable
fun DeliveryCard(order: OrderDetail, serverDate: String?, canChangeDate: Boolean = false, onChangeDate: () -> Unit = {}) {
    val context = LocalContext.current
    val lines = deliveryLinesOf(order, canChangeDate)
    val due = serverDate?.let { dueMarkOf(order.status, order.listDate ?: order.deliveryDate, it) }
    GlassCard(Modifier.fillMaxWidth().testTag(AdminOrderTags.DETAIL_DELIVERY)) {
        Text(stringResource(R.string.a_sec_delivery), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(stringResource(R.string.a_requested_date), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalArrangement = Arrangement.spacedBy(Spacing.xs), itemVerticalAlignment = Alignment.CenterVertically) {
            Text(
                "${formatWeekdayDate(lines.requestedDate, serverDate)} · ${order.slot.start} – ${order.slot.end}",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.testTag(AdminOrderTags.ORDER_REQUESTED_DATE),
            )
            if (due != null) DueMarkChip(due.text(context), painterResource(R.drawable.ic_clock), Modifier.testTag(AdminOrderTags.DETAIL_DUE))
        }
        lines.expectedDate?.let { date ->
            // The whole line is the tap target (48 dp) so the date is easy to hit.
            val tap = if (lines.expectedTappable) Modifier.heightIn(min = Sizes.touchTarget).clickable(role = Role.Button, onClick = onChangeDate) else Modifier
            Text(
                "${stringResource(R.string.a_expected_date)}: ${formatWeekdayDate(date, serverDate)}",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.fillMaxWidth().then(tap).testTag(AdminOrderTags.ORDER_EXPECTED_DATE),
            )
        }
        Text(order.customerAddress, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag(AdminOrderTags.DETAIL_ADDRESS))
        Text(order.districtName, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
