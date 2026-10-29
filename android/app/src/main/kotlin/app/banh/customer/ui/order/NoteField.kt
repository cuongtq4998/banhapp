package app.banh.customer.ui.order

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderIntent

private const val NOTE_LINES = 3

/**
 * The optional note with its counter (FR-18). A 201st typed or pasted character is not inserted by the store; the
 * message `ERR_NOTE_MAX` then shows beside the field (AC-26).
 */
@Composable
fun NoteField(state: OrderFlowState, onIntent: (OrderIntent) -> Unit) {
    val note = state.draft.note
    val length = note.codePointCount(0, note.length)
    FormTextField(
        value = note,
        onValueChange = { onIntent(OrderIntent.EditNote(it)) },
        label = stringResource(R.string.field_note),
        testTag = TestTags.ORDER_FIELD_NOTE,
        focusRequester = remember { FocusRequester() },
        // Enter inserts a new line in the note, so the action is the default one (UI document 5.7).
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text, imeAction = ImeAction.Default),
        messages = FieldMessages(
            errorText = if (state.noteLimitHit) stringResource(R.string.err_note_max, state.noteMaxLength) else null,
            errorTestTag = TestTags.ORDER_NOTE_ERROR,
            counterText = stringResource(R.string.note_counter, length, state.noteMaxLength),
            counterTestTag = TestTags.ORDER_NOTE_COUNTER,
        ),
        singleLine = false,
        minLines = NOTE_LINES,
    )
}
