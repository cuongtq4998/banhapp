package app.banh.admin.ui.orders

import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** The native graphical date dialog for "pick one date" (FR-10). The dialog reports UTC midnight, read back as a plain date. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OneDatePicker(onDismiss: () -> Unit, onPicked: (LocalDate) -> Unit) {
    val state = rememberDatePickerState()
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(
                enabled = state.selectedDateMillis != null,
                onClick = { state.selectedDateMillis?.let { onPicked(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) } },
            ) { Text(stringResource(R.string.a_filter_date)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.a_back)) } },
    ) {
        DatePicker(state = state)
    }
}
