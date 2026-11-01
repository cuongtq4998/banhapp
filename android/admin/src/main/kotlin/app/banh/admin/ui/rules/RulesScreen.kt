package app.banh.admin.ui.rules

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.rules.LimitWarning
import app.banh.admin.rules.RulesBanner
import app.banh.admin.rules.RulesBusy
import app.banh.admin.rules.RulesField
import app.banh.admin.rules.RulesIntent
import app.banh.admin.rules.RulesState
import app.banh.admin.rules.RulesViewModel
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.forms.DiscardDialog
import app.banh.admin.ui.forms.FormField
import app.banh.admin.ui.forms.FormScreen
import app.banh.admin.ui.forms.GatedPage
import app.banh.core.common.formatDate
import app.banh.core.design.GlassCard
import app.banh.core.design.InfoMessageView
import app.banh.core.design.Spacing

/** S-A9 bound to its view model; the values come from the shared settings once they are loaded. */
@Composable
fun RulesRoute(container: AdminContainer, store: SettingsViewModel, onBack: () -> Unit) {
    val shared by store.state.collectAsStateWithLifecycle()
    GatedPage(stringResource(R.string.a_row_rules), onBack, shared.phase, store::reload) {
        val viewModel = viewModel<RulesViewModel>(
            key = "rules",
            factory = viewModelFactory { initializer { RulesViewModel(RulesState(checkNotNull(shared.settings).ordering), container.owner, store) } },
        )
        val state by viewModel.state.collectAsStateWithLifecycle()
        LaunchedEffect(state.done) { if (state.done) onBack() }
        RulesScreen(state, viewModel::dispatch, onBack)
    }
}

@Composable
fun RulesScreen(state: RulesState, dispatch: (RulesIntent) -> Unit, onBack: () -> Unit) {
    FormScreen(
        title = stringResource(R.string.a_row_rules),
        onBack = { if (state.changed) dispatch(RulesIntent.Back) else onBack() },
        saveLabel = stringResource(R.string.a_save),
        saveTag = AdminTags.RULES_SAVE,
        canSave = state.canSave,
        saving = state.busy != RulesBusy.NONE,
        onSave = { dispatch(RulesIntent.Save) },
        message = when (state.banner) {
            RulesBanner.ERROR -> stringResource(R.string.a_err_generic)
            RulesBanner.OFFLINE -> stringResource(R.string.a_offline_save)
            null -> null
        },
    ) {
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                FormField(stringResource(R.string.a_f_limit), state.limit, { dispatch(RulesIntent.Limit(it)) }, AdminTags.RULES_LIMIT, state.problems[RulesField.LIMIT], AdminTags.rulesError(RulesField.LIMIT), keyboard = KeyboardType.Number)
                FormField(stringResource(R.string.a_f_lead), state.lead, { dispatch(RulesIntent.Lead(it)) }, AdminTags.RULES_LEAD, state.problems[RulesField.LEAD], AdminTags.rulesError(RulesField.LEAD), keyboard = KeyboardType.Number)
                FormField(stringResource(R.string.a_f_min), state.min, { dispatch(RulesIntent.Min(it)) }, AdminTags.RULES_MIN, state.problems[RulesField.MIN], AdminTags.rulesError(RulesField.MIN), keyboard = KeyboardType.Number)
                Text(stringResource(R.string.a_horizon_fixed), style = androidx.compose.material3.MaterialTheme.typography.bodyMedium)
            }
        }
        InfoMessageView(stringResource(R.string.a_rules_effect), painterResource(R.drawable.ic_error))
    }
    state.warning?.let { WarningDialog(it, dispatch) }
    if (state.discard) DiscardDialog(onDiscard = onBack, onKeep = { dispatch(RulesIntent.Dismiss) })
}

/** AC-35: the dates that hold more cakes than the new limit; saving cancels nothing, and the text says so. */
@Composable
private fun WarningDialog(warning: LimitWarning, dispatch: (RulesIntent) -> Unit) {
    AlertDialog(
        onDismissRequest = { dispatch(RulesIntent.Dismiss) },
        modifier = Modifier.testTag(AdminTags.RULES_WARN_DIALOG),
        title = { Text(stringResource(R.string.a_limit_warn_title)) },
        text = {
            Column(Modifier.heightIn(max = 320.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                Text(stringResource(R.string.a_limit_warn_body, warning.days.size))
                warning.days.forEach { Text(stringResource(R.string.a_over_limit_day, formatDate(it.date), it.cakesAccepted)) }
            }
        },
        confirmButton = {
            if (warning.afterSave) {
                TextButton(onClick = { dispatch(RulesIntent.Dismiss) }, modifier = Modifier.testTag(AdminTags.RULES_WARN_CONFIRM)) { Text(stringResource(R.string.a_back)) }
            } else {
                TextButton(onClick = { dispatch(RulesIntent.SaveAnyway) }, modifier = Modifier.testTag(AdminTags.RULES_WARN_CONFIRM)) { Text(stringResource(R.string.a_save_anyway)) }
            }
        },
        dismissButton = if (warning.afterSave) null else ({ TextButton(onClick = { dispatch(RulesIntent.Dismiss) }, modifier = Modifier.testTag(AdminTags.RULES_WARN_BACK)) { Text(stringResource(R.string.a_back)) } }),
    )
}
