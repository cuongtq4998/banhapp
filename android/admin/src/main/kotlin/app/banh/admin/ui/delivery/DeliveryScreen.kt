package app.banh.admin.ui.delivery

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.delivery.DeliveryIntent
import app.banh.admin.delivery.DeliveryToast
import app.banh.admin.delivery.DeliveryViewModel
import app.banh.admin.delivery.SheetKind
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.AdminToast
import app.banh.admin.ui.forms.GatedPage
import app.banh.admin.ui.forms.OwnerToastHost
import app.banh.admin.ui.forms.ToggleRow
import app.banh.core.common.formatVnd
import app.banh.core.design.BackControl
import app.banh.core.design.BanhInlineTopBar
import app.banh.core.design.BanhScreen
import app.banh.core.design.GlassCard
import app.banh.core.design.Spacing
import app.banh.core.model.DeliverySlot
import app.banh.core.model.District

/** S-A10: districts with fees and time slots on one screen; a row opens its sheet, a switch saves at once. */
@Composable
fun DeliveryRoute(container: AdminContainer, store: SettingsViewModel, onBack: () -> Unit) {
    val shared by store.state.collectAsStateWithLifecycle()
    GatedPage(stringResource(R.string.a_row_delivery_set), onBack, shared.phase, store::reload) {
        val model = viewModel<DeliveryViewModel>(key = "delivery", factory = viewModelFactory { initializer { DeliveryViewModel(container.owner, store) } })
        val state by model.state.collectAsStateWithLifecycle()
        val settings = checkNotNull(shared.settings)
        BanhScreen(
            topBar = { BanhInlineTopBar(stringResource(R.string.a_row_delivery_set), BackControl(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.a_back), AdminTags.NAV_BACK), onBack) },
        ) { padding ->
            LazyColumn(
                modifier = Modifier.testTag(AdminTags.DELIVERY_LIST),
                contentPadding = PaddingValues(start = Spacing.screenMargin, end = Spacing.screenMargin, top = padding.calculateTopPadding() + Spacing.sm, bottom = Spacing.xxl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                item { SectionHeader(R.string.a_sec_districts, R.string.a_add_district, AdminTags.DISTRICT_ADD) { model.dispatch(DeliveryIntent.OpenDistrict(null)) } }
                if (settings.districts.isEmpty()) item { Text(stringResource(R.string.a_districts_empty)) }
                items(settings.districts, key = { it.districtId }) { d ->
                    DistrictRow(d, d.districtId in state.pending, { model.dispatch(DeliveryIntent.OpenDistrict(d)) }) { model.dispatch(DeliveryIntent.Toggle(SheetKind.DISTRICT, d.districtId, it)) }
                }
                item { SectionHeader(R.string.a_sec_slots, R.string.a_add_slot, AdminTags.SLOT_ADD) { model.dispatch(DeliveryIntent.OpenSlot(null)) } }
                if (settings.slots.isEmpty()) item { Text(stringResource(R.string.a_slots_empty)) }
                items(settings.slots, key = { it.slotId }) { s ->
                    SlotRow(s, s.slotId in state.pending, { model.dispatch(DeliveryIntent.OpenSlot(s)) }) { model.dispatch(DeliveryIntent.Toggle(SheetKind.SLOT, s.slotId, it)) }
                }
            }
        }
        state.sheet?.let { DeliverySheetView(it, model::dispatch) }
        OwnerToastHost(shared.toast, store::toastShown)
        val message = when (state.toast) {
            DeliveryToast.LAST_DISTRICT -> R.string.a_err_last_district
            DeliveryToast.LAST_SLOT -> R.string.a_err_last_slot
            DeliveryToast.ERROR -> R.string.a_err_generic
            DeliveryToast.OFFLINE -> R.string.a_offline_save
            null -> null
        }
        AdminToast(message?.let { stringResource(it) }, { model.dispatch(DeliveryIntent.ToastShown) }, HapticFeedbackType.Reject)
    }
}

@Composable
private fun SectionHeader(title: Int, addLabel: Int, tag: String, onAdd: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = Spacing.sm), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
        Text(stringResource(title), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
        val label = stringResource(addLabel)
        IconButton(onClick = onAdd, modifier = Modifier.testTag(tag).semantics { contentDescription = label }) { Icon(painterResource(R.drawable.ic_add), contentDescription = null) }
    }
}

@Composable
private fun DistrictRow(district: District, pending: Boolean, onOpen: () -> Unit, onToggle: (Boolean) -> Unit) {
    GlassCard(onClick = onOpen, modifier = Modifier.fillMaxWidth().alpha(if (pending) PENDING_ALPHA else 1f).testTag(AdminTags.districtRow(district.districtId))) {
        Text(district.name, style = MaterialTheme.typography.titleMedium)
        Text(formatVnd(district.deliveryFeeVnd), style = MaterialTheme.typography.bodyLarge)
        ToggleRow(stringResource(R.string.a_active), district.isActive, onToggle, AdminTags.districtToggle(district.districtId), enabled = !pending)
    }
}

@Composable
private fun SlotRow(slot: DeliverySlot, pending: Boolean, onOpen: () -> Unit, onToggle: (Boolean) -> Unit) {
    GlassCard(onClick = onOpen, modifier = Modifier.fillMaxWidth().alpha(if (pending) PENDING_ALPHA else 1f).testTag(AdminTags.slotRow(slot.slotId))) {
        Text("${slot.start} – ${slot.end}", style = MaterialTheme.typography.titleMedium)
        ToggleRow(stringResource(R.string.a_active), slot.isActive, onToggle, AdminTags.slotToggle(slot.slotId), enabled = !pending)
    }
}

private const val PENDING_ALPHA = 0.5f
