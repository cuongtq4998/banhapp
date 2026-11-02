package app.banh.admin.ui.forms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.ImeAction
import app.banh.admin.owner.Problem
import app.banh.core.design.Sizes
import app.banh.core.design.Spacing

/**
 * A labelled text field with the error under it (form rules): the label is visible above the field, the message names the field and
 * has its own test id. [counterMax] shows "n/max" for the long texts.
 */
@Composable
fun FormField(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    tag: String,
    problem: Problem?,
    errorTag: String,
    modifier: Modifier = Modifier,
    keyboard: KeyboardType = KeyboardType.Text,
    multiline: Boolean = false,
    counterMax: Int? = null,
    enabled: Boolean = true,
    suffix: String? = null,
) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Text(label, style = MaterialTheme.typography.labelLarge)
        OutlinedTextField(
            value = value,
            onValueChange = onChange,
            enabled = enabled,
            isError = problem != null,
            singleLine = !multiline,
            minLines = if (multiline) 3 else 1,
            suffix = suffix?.let { { Text(it) } },
            keyboardOptions = KeyboardOptions(keyboardType = keyboard, imeAction = if (multiline) ImeAction.Default else ImeAction.Next),
            supportingText = {
                Column {
                    if (problem != null) Text(problemText(label, problem), color = MaterialTheme.colorScheme.error, modifier = Modifier.testTag(errorTag))
                    if (counterMax != null) Text("${value.length}/$counterMax", style = MaterialTheme.typography.bodySmall)
                }
            },
            modifier = Modifier.fillMaxWidth().testTag(tag),
        )
    }
}

/** A label with a switch; the whole row toggles, so the target is large (design: `ToggleRow`). */
@Composable
fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit, tag: String, modifier: Modifier = Modifier, enabled: Boolean = true) {
    Row(
        modifier = modifier.fillMaxWidth().heightIn(min = Sizes.touchTarget)
            .toggleable(value = checked, enabled = enabled, role = Role.Switch, onValueChange = onChange)
            .testTag(tag).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f).padding(end = Spacing.md))
        Switch(checked = checked, onCheckedChange = null, enabled = enabled)
    }
}
