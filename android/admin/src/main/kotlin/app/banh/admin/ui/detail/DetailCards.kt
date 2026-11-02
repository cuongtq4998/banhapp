package app.banh.admin.ui.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.ui.graphics.Color
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import app.banh.admin.R
import app.banh.admin.orderdetail.FeeRow
import app.banh.admin.orderdetail.OrderDetailIntent
import app.banh.admin.orderdetail.amountToCollectOf
import app.banh.admin.orderdetail.feeRowOf
import app.banh.core.model.OrderAction
import app.banh.admin.ui.AdminOrderTags
import app.banh.admin.ui.text
import app.banh.admin.ui.textRes
import app.banh.core.common.dueMarkOf
import app.banh.core.common.formatInstant
import app.banh.core.common.formatVnd
import app.banh.core.common.formatWeekdayDate
import app.banh.core.design.ContactButton
import app.banh.core.design.DueMarkChip
import app.banh.core.design.GlassCard
import app.banh.core.design.Spacing
import app.banh.core.model.OrderDetail

@Composable
private fun SectionLabel(res: Int) {
    Text(stringResource(res), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

/** Name, phone (selectable) and the two contact buttons (FR-15). */
@Composable
fun CustomerCard(order: OrderDetail, onCall: () -> Unit, onZalo: () -> Unit) {
    GlassCard(Modifier.fillMaxWidth()) {
        SectionLabel(R.string.a_sec_customer)
        Text(order.customerName, style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag(AdminOrderTags.DETAIL_CUSTOMER))
        SelectionContainer { Text(order.customerPhone, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag(AdminOrderTags.DETAIL_PHONE)) }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            ContactButton(stringResource(R.string.a_call, order.customerPhone), painterResource(R.drawable.ic_call), onCall, Modifier.testTag(AdminOrderTags.DETAIL_CALL))
            ContactButton(stringResource(R.string.a_zalo), painterResource(R.drawable.ic_chat), onZalo, Modifier.testTag(AdminOrderTags.DETAIL_ZALO))
        }
    }
}

/** Weekday, date and slot with the red mark when due; address and district. */
@Composable
fun DeliveryCard(order: OrderDetail, serverDate: String?) {
    val context = LocalContext.current
    val due = serverDate?.let { dueMarkOf(order.status, order.listDate ?: order.deliveryDate, it) }
    GlassCard(Modifier.fillMaxWidth().testTag(AdminOrderTags.DETAIL_DELIVERY)) {
        SectionLabel(R.string.a_sec_delivery)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(Spacing.sm), verticalArrangement = Arrangement.spacedBy(Spacing.xs), itemVerticalAlignment = Alignment.CenterVertically) {
            Text("${formatWeekdayDate(order.deliveryDate, serverDate)} · ${order.slot.start} – ${order.slot.end}", style = MaterialTheme.typography.titleMedium)
            if (due != null) DueMarkChip(due.text(context), painterResource(R.drawable.ic_clock), Modifier.testTag(AdminOrderTags.DETAIL_DUE))
        }
        Text(order.customerAddress, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag(AdminOrderTags.DETAIL_ADDRESS))
        Text(order.districtName, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Cakes as stored, the cakes sum, the fee (pending until typed) and the amount to collect (AC-24, AC-51). */
@Composable
fun CakesCard(order: OrderDetail, dispatch: (OrderDetailIntent) -> Unit = {}, canCorrectFee: Boolean = false) {
    GlassCard(Modifier.fillMaxWidth().testTag(AdminOrderTags.DETAIL_CAKES)) {
        SectionLabel(R.string.a_sec_cakes)
        order.items.forEachIndexed { index, line ->
            Column(Modifier.testTag(AdminOrderTags.detailCake(index))) {
                Text("${line.quantity} × ${line.productName}", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
                AmountRow("${formatVnd(line.unitPriceVnd)} × ${line.quantity}", formatVnd(line.lineTotalVnd))
            }
        }
        AmountRow(stringResource(R.string.a_cakes_total), formatVnd(order.itemsSubtotalVnd), Modifier.testTag(AdminOrderTags.DETAIL_TOTAL))
        FeeRowView(feeRowOf(order))
        if (canCorrectFee) {
            TextButton(onClick = { dispatch(OrderDetailIntent.Tap(OrderAction.CORRECT_FEE)) }, modifier = Modifier.testTag(AdminOrderTags.ORDER_FEE_CORRECT)) {
                Text(stringResource(R.string.a_fee_correct))
            }
        }
        amountToCollectOf(order)?.let { AmountRow(stringResource(R.string.a_total_collect), formatVnd(it), Modifier.testTag(AdminOrderTags.ORDER_TOTAL_COLLECT), strong = true) }
    }
}

@Composable
private fun FeeRowView(row: FeeRow) {
    val label = stringResource(R.string.a_fee)
    val tag = Modifier.testTag(AdminOrderTags.ORDER_FEE)
    when (row) {
        is FeeRow.Pending -> Column {
            AmountRow(label, stringResource(R.string.a_fee_pending), tag, muted = true)
            row.estimateVnd?.let {
                Text(stringResource(R.string.a_fee_estimate_line, formatVnd(it)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.testTag(AdminOrderTags.ORDER_FEE_ESTIMATE))
            }
        }
        FeeRow.Free -> AmountRow(label, stringResource(R.string.a_fee_free), tag)
        is FeeRow.Amount -> AmountRow(label, formatVnd(row.vnd), tag)
    }
}

/** Corrections newest first; no card and no heading when there are none. */
@Composable
fun FeeHistoryCard(order: OrderDetail, serverDate: String?) {
    if (order.feeCorrections.isEmpty()) return
    GlassCard(Modifier.fillMaxWidth().testTag(AdminOrderTags.ORDER_FEE_HISTORY)) {
        SectionLabel(R.string.a_fee_history)
        order.feeCorrections.sortedByDescending { it.changedAt }.forEachIndexed { index, change ->
            val who = change.changedByName ?: stringResource(R.string.a_hist_customer)
            Column(Modifier.testTag(AdminOrderTags.feeHistoryRow(index + 1))) {
                Text("$who, ${formatInstant(change.changedAt, serverDate)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(stringResource(R.string.a_fee_change_line, formatVnd(change.oldFeeVnd), formatVnd(change.newFeeVnd)), style = MaterialTheme.typography.bodyLarge)
            }
        }
    }
}

@Composable
private fun AmountRow(label: String, amount: String, modifier: Modifier = Modifier, strong: Boolean = false, muted: Boolean = false) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Text(amount, style = MaterialTheme.typography.bodyLarge, fontWeight = if (strong) FontWeight.Bold else FontWeight.Medium, color = if (muted) MaterialTheme.colorScheme.onSurfaceVariant else Color.Unspecified)
    }
}

@Composable
fun NoteCard(note: String) {
    GlassCard(Modifier.fillMaxWidth().testTag(AdminOrderTags.DETAIL_NOTE)) {
        SectionLabel(R.string.a_sec_note)
        Text(note, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
fun ReasonCard(order: OrderDetail) {
    val reason = order.cancelReason ?: return
    GlassCard(Modifier.fillMaxWidth().testTag(AdminOrderTags.DETAIL_REASON)) {
        SectionLabel(R.string.a_sec_reason)
        Text(stringResource(reason.textRes()), style = MaterialTheme.typography.bodyLarge)
    }
}

/** "Placed at" and "last changed by" (FR-14); the name is "khách hàng" for an order nobody changed yet. */
@Composable
fun HistoryLines(order: OrderDetail, serverDate: String?) {
    val actor = order.lastChange?.actorName ?: stringResource(R.string.a_hist_customer)
    val at = formatInstant(order.lastChange?.at ?: order.createdAt, serverDate)
    Column {
        Text(stringResource(R.string.a_placed_at, formatInstant(order.createdAt, serverDate)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            stringResource(R.string.a_last_changed, actor, at),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.testTag(AdminOrderTags.DETAIL_LAST_CHANGED),
        )
    }
}
