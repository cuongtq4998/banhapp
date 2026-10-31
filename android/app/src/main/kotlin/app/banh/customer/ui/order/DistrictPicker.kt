package app.banh.customer.ui.order

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.matchParentSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.District
import app.banh.customer.ui.common.ErrorMessage
import app.banh.customer.ui.common.InfoMessage
import app.banh.customer.design.Radii
import app.banh.customer.design.Spacing
import app.banh.customer.ui.common.formatMoney

private const val SPINNER_SIZE_DP = 24
private const val SPINNER_STROKE_DP = 2

/**
 * `PickerField` for the served districts (FR-8, AC-11): only listed districts can be chosen, the fee shows under the
 * field once one is chosen, and loading, failure and "no district" have their own states (UI document 5.7).
 */
@Composable
fun DistrictPicker(
    districts: Load<List<District>>,
    selectedId: String?,
    errorText: String?,
    focusRequester: FocusRequester,
    onSelect: (String) -> Unit,
    onRetry: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        when (districts) {
            Load.Loading -> PickerField(emptyList(), null, null, enabled = false, loading = true, focusRequester = focusRequester, onSelect = onSelect)
            is Load.Failed -> {
                PickerField(emptyList(), null, null, enabled = false, loading = false, focusRequester = focusRequester, onSelect = onSelect)
                ErrorMessage(
                    text = stringResource(R.string.district_err),
                    modifier = Modifier.testTag(TestTags.ORDER_DISTRICT_ERROR),
                    actionLabel = stringResource(R.string.common_retry),
                    actionTestTag = TestTags.STATE_RETRY,
                    onAction = onRetry,
                )
            }
            is Load.Ready ->
                if (districts.value.isEmpty()) {
                    InfoMessage(stringResource(R.string.district_empty), Modifier.testTag(TestTags.ORDER_DISTRICT_EMPTY))
                } else {
                    val selected = districts.value.firstOrNull { it.id == selectedId }
                    PickerField(districts.value, selected, errorText, enabled = true, loading = false, focusRequester = focusRequester, onSelect = onSelect)
                    if (selected != null) {
                        Text(
                            stringResource(R.string.district_fee, formatMoney(selected.deliveryFeeVnd)),
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.testTag(TestTags.ORDER_DISTRICT_FEE),
                        )
                    }
                }
        }
    }
}

@Composable
private fun PickerField(
    districts: List<District>,
    selected: District?,
    errorText: String?,
    enabled: Boolean,
    loading: Boolean,
    focusRequester: FocusRequester,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val label = stringResource(R.string.field_district)
    val valueText = selected?.name ?: stringResource(R.string.district_placeholder)
    val description = "$label, $valueText"
    Box {
        // The text field only draws; the overlay on top takes the taps and carries the semantics of one control.
        OutlinedTextField(
            value = valueText,
            onValueChange = {},
            readOnly = true,
            label = { Text(label) },
            isError = errorText != null,
            trailingIcon = {
                if (loading) {
                    CircularProgressIndicator(Modifier.size(SPINNER_SIZE_DP.dp), strokeWidth = SPINNER_STROKE_DP.dp)
                } else {
                    Icon(painterResource(R.drawable.ic_chevron_right), contentDescription = null)
                }
            },
            shape = RoundedCornerShape(Radii.image),
            modifier = Modifier.fillMaxWidth().clearAndSetSemantics { },
        )
        Box(
            Modifier
                .matchParentSize()
                .focusRequester(focusRequester)
                .testTag(TestTags.ORDER_FIELD_DISTRICT)
                .semantics { contentDescription = description; if (errorText != null) error(errorText) }
                .clickable(enabled = enabled, role = Role.DropdownList) { expanded = true },
        )
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            districts.forEach { district ->
                DropdownMenuItem(
                    text = {
                        Column {
                            Text(district.name)
                            Text(stringResource(R.string.district_fee, formatMoney(district.deliveryFeeVnd)), style = MaterialTheme.typography.bodySmall)
                        }
                    },
                    onClick = {
                        expanded = false
                        onSelect(district.id)
                    },
                    modifier = Modifier.testTag(TestTags.orderDistrictRow(district.id)),
                )
            }
        }
    }
    if (errorText != null) {
        Text(
            errorText,
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.testTag(TestTags.orderFieldError("district")),
        )
    }
}
