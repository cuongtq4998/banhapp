package app.banh.customer.ui.order

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import app.banh.customer.design.Radii
import app.banh.customer.design.Spacing

/** A line under a text field: the error on the left, an optional counter on the right. */
data class FieldMessages(
    val errorText: String?,
    val errorTestTag: String,
    val counterText: String? = null,
    val counterTestTag: String? = null,
)

/**
 * Labelled text field of S-7 (`TextField`): the label stays visible above the value, an error appears beside the field
 * and is announced with it, and the field can take the focus from outside (first failing field, AC-12).
 */
@Composable
fun FormTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    testTag: String,
    focusRequester: FocusRequester,
    keyboardOptions: KeyboardOptions,
    messages: FieldMessages,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true,
    minLines: Int = 1,
) {
    val errorText = messages.errorText
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        isError = errorText != null,
        supportingText = if (errorText != null || messages.counterText != null) {
            { FieldMessageLine(messages) }
        } else {
            null
        },
        keyboardOptions = keyboardOptions,
        singleLine = singleLine,
        minLines = minLines,
        shape = RoundedCornerShape(Radii.image),
        modifier = modifier
            .fillMaxWidth()
            .focusRequester(focusRequester)
            .testTag(testTag)
            .semantics { if (errorText != null) error(errorText) },
    )
}

@Composable
private fun FieldMessageLine(messages: FieldMessages) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        if (messages.errorText != null) {
            Text(messages.errorText, color = MaterialTheme.colorScheme.error, modifier = Modifier.weight(1f).testTag(messages.errorTestTag))
        }
        if (messages.counterText != null) {
            val counterModifier = if (messages.counterTestTag != null) Modifier.testTag(messages.counterTestTag) else Modifier
            Text(messages.counterText, modifier = counterModifier)
        }
    }
}
