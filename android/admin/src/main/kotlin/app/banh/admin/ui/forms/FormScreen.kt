package app.banh.admin.ui.forms

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.banh.admin.R
import app.banh.admin.ui.AdminTags
import app.banh.core.design.BackControl
import app.banh.core.design.BanhInlineTopBar
import app.banh.core.design.BanhScreen
import app.banh.core.design.BottomActionBar
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.PrimaryButton
import app.banh.core.design.Spacing

/** The shared frame of the form screens: top bar with back, scrolling body, and the bottom bar with the message and the save button. */
@Composable
fun FormScreen(
    title: String,
    onBack: () -> Unit,
    saveLabel: String,
    saveTag: String,
    canSave: Boolean,
    saving: Boolean,
    onSave: () -> Unit,
    modifier: Modifier = Modifier,
    message: String? = null,
    bottomExtra: @Composable () -> Unit = {},
    content: @Composable () -> Unit,
) {
    BackHandler(onBack = onBack)
    Box(modifier.fillMaxSize()) {
        BanhScreen(
            topBar = { BanhInlineTopBar(title, BackControl(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.a_back), AdminTags.NAV_BACK), onBack) },
            bottomBar = {
                BottomActionBar(Modifier.imePadding()) {
                    if (message != null) ErrorMessageView(message, painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.OWNER_SAVE_ERROR))
                    bottomExtra()
                    PrimaryButton(saveLabel, onSave, Modifier.testTag(saveTag), enabled = canSave, loading = saving)
                }
            },
        ) { padding ->
            Column(
                Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = Spacing.screenMargin).padding(top = Spacing.sm, bottom = BAR_ROOM),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) { content() }
        }
    }
}

private val BAR_ROOM = 120.dp

/** "Discard unsaved changes?" (dirty back, part 2 of the UI spec). */
@Composable
fun DiscardDialog(onDiscard: () -> Unit, onKeep: () -> Unit) {
    AlertDialog(
        onDismissRequest = onKeep,
        title = { Text(stringResource(R.string.a_discard_title)) },
        text = { Text(stringResource(R.string.a_discard_body)) },
        confirmButton = { TextButton(onClick = onDiscard, modifier = Modifier.testTag(AdminTags.DISCARD_CONFIRM)) { Text(stringResource(R.string.a_discard)) } },
        dismissButton = { TextButton(onClick = onKeep, modifier = Modifier.testTag(AdminTags.DISCARD_KEEP)) { Text(stringResource(R.string.a_keep_editing)) } },
    )
}
