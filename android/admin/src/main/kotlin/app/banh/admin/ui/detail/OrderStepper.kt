package app.banh.admin.ui.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.banh.admin.R
import app.banh.admin.orderdetail.StepState
import app.banh.admin.orderdetail.stepStatesOf
import app.banh.admin.ui.AdminOrderTags
import app.banh.core.common.formatDate
import app.banh.core.design.GlassCard
import app.banh.core.design.Spacing
import app.banh.core.model.OrderDetail

private val STEP_NAMES = listOf(R.string.a_status_received, R.string.a_status_processing, R.string.a_status_scheduled, R.string.a_status_delivering, R.string.a_status_finished)
private const val SCHEDULED_ROW = 2
private val MARKER = 24.dp
private val DOT = 10.dp
private val RING = 2.dp
private val ROW_MIN = 48.dp

/** Read-only five-row progress card; absent for Cancelled orders. */
@Composable
fun OrderStepper(order: OrderDetail, serverDate: String?) {
    val states = stepStatesOf(order.status) ?: return
    GlassCard(Modifier.fillMaxWidth().testTag(AdminOrderTags.ORDER_STEPPER)) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            states.forEachIndexed { index, state ->
                val name = stringResource(STEP_NAMES[index])
                val stateText = stringResource(state.textRes())
                val label = stringResource(R.string.a_step_a11y, index + 1, name, stateText)
                // One element per row: the label replaces the parts.
                Row(
                    Modifier.fillMaxWidth().heightIn(min = ROW_MIN).testTag(AdminOrderTags.orderStep(index + 1)).clearAndSetSemantics { contentDescription = label },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Marker(state)
                    Spacer(Modifier.width(Spacing.sm))
                    Text(name, style = MaterialTheme.typography.bodyLarge, fontWeight = if (state == StepState.CURRENT) FontWeight.Bold else FontWeight.Normal)
                    val expected = order.expectedDeliveryDate
                    if (index == SCHEDULED_ROW && expected != null && state != StepState.NEXT) {
                        Spacer(Modifier.width(Spacing.sm))
                        Text(formatDate(expected, serverDate), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

private fun StepState.textRes(): Int = when (this) {
    StepState.DONE -> R.string.a_step_done
    StepState.CURRENT -> R.string.a_step_current
    StepState.NEXT -> R.string.a_step_next
}

// Shape carries the state as well as colour: check, ring with dot, empty ring.
@Composable
private fun Marker(state: StepState) {
    val brand = MaterialTheme.colorScheme.primary
    when (state) {
        StepState.DONE -> Icon(painterResource(R.drawable.ic_check), contentDescription = null, tint = brand, modifier = Modifier.size(MARKER))
        StepState.CURRENT -> Box(Modifier.size(MARKER).border(RING, brand, CircleShape), contentAlignment = Alignment.Center) {
            Box(Modifier.size(DOT).background(brand, CircleShape))
        }
        StepState.NEXT -> Box(Modifier.size(MARKER).border(RING, MaterialTheme.colorScheme.outline, CircleShape))
    }
}
