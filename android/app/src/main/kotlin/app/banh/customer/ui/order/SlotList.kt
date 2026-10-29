package app.banh.customer.ui.order

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import app.banh.customer.TestTags
import app.banh.customer.data.catalog.Slot
import app.banh.customer.design.Sizes
import app.banh.customer.design.Spacing

/** The same fixed slots for every date (AC-10); single choice. A selected chip is filled, not only coloured (UI document 9). */
@Composable
fun SlotList(slots: List<Slot>, selectedSlotId: String?, onSelect: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        slots.forEach { slot ->
            val selected = slot.id == selectedSlotId
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = Sizes.touchTarget)
                    .testTag(TestTags.orderSlot(slot.id))
                    .selectable(selected = selected, role = Role.RadioButton, onClick = { onSelect(slot.id) }),
                shape = CircleShape,
                color = if (selected) MaterialTheme.colorScheme.primary else Color.Transparent,
                contentColor = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                border = BorderStroke(Sizes.hairline, MaterialTheme.colorScheme.primary),
            ) {
                Text(
                    text = slotLabel(slot),
                    style = MaterialTheme.typography.labelLarge,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.md).fillMaxWidth(),
                )
            }
        }
    }
}
