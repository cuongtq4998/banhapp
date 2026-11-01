package app.banh.admin.ui.cakes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import app.banh.admin.R
import app.banh.admin.cakes.CakeBanner
import app.banh.admin.cakes.CakeBusy
import app.banh.admin.cakes.CakeField
import app.banh.admin.cakes.CakeFormState
import app.banh.admin.cakes.CakeIntent
import app.banh.admin.cakes.CakeToast
import app.banh.admin.cakes.DESC_MAX
import app.banh.admin.photo.ImageSource
import app.banh.admin.ui.AdminTags
import app.banh.admin.ui.AdminToast
import app.banh.admin.ui.forms.FormField
import app.banh.admin.ui.forms.FormScreen
import app.banh.admin.ui.forms.ToggleRow
import app.banh.core.design.GlassCard
import app.banh.core.design.InfoMessageView
import app.banh.core.design.SecondaryButton
import app.banh.core.design.Spacing
import androidx.compose.ui.hapticfeedback.HapticFeedbackType

/** S-A8, stateless: the same form adds a cake (picture required) and changes one (picture fixed, switch, remove). */
@Composable
fun CakeFormScreen(
    state: CakeFormState,
    images: ImageSource,
    dispatch: (CakeIntent) -> Unit,
    onBack: () -> Unit,
    onPick: () -> Unit,
) {
    val uploading = state.busy == CakeBusy.SAVING && state.isAdd
    FormScreen(
        title = state.original?.name ?: stringResource(R.string.a_add_cake_title),
        onBack = { if (state.changed) dispatch(CakeIntent.Back) else onBack() },
        saveLabel = stringResource(if (state.isAdd) R.string.a_add_cake_save else R.string.a_save),
        saveTag = AdminTags.CAKE_FORM_SAVE,
        canSave = state.canSave,
        saving = state.busy == CakeBusy.SAVING,
        onSave = { dispatch(CakeIntent.Save) },
        message = bannerText(state.banner),
        bottomExtra = { if (uploading) UploadBar(state.progress) { dispatch(CakeIntent.CancelUpload) } },
    ) {
        val readOnly = state.busy != CakeBusy.NONE
        if (state.isAdd) PictureArea(state, onPick, dispatch) else EditPicture(state, images)
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                FormField(stringResource(R.string.a_f_cake_name), state.name, { dispatch(CakeIntent.Name(it)) }, AdminTags.CAKE_FORM_NAME, state.problems[CakeField.NAME], AdminTags.cakeFormError(CakeField.NAME), enabled = !readOnly)
                FormField(stringResource(R.string.a_f_cake_desc), state.description, { dispatch(CakeIntent.Description(it)) }, AdminTags.CAKE_FORM_DESC, state.problems[CakeField.DESC], AdminTags.cakeFormError(CakeField.DESC), multiline = true, counterMax = DESC_MAX, enabled = !readOnly)
                FormField(stringResource(R.string.a_f_price), state.price, { dispatch(CakeIntent.Price(it)) }, AdminTags.CAKE_FORM_PRICE, state.problems[CakeField.PRICE], AdminTags.cakeFormError(CakeField.PRICE), keyboard = KeyboardType.Number, enabled = !readOnly, suffix = "đ")
            }
        }
        if (state.isAdd) {
            InfoMessageView(stringResource(R.string.a_new_cake_active), painterResource(R.drawable.ic_error))
        } else {
            InfoMessageView(stringResource(R.string.a_new_orders_only), painterResource(R.drawable.ic_error))
            GlassCard(Modifier.fillMaxWidth()) {
                ToggleRow(stringResource(R.string.a_cake_active_toggle), state.active, { dispatch(CakeIntent.Active(it)) }, AdminTags.CAKE_FORM_ACTIVE, enabled = !readOnly)
                androidx.compose.material3.Text(stringResource(R.string.a_cake_hidden_help), style = androidx.compose.material3.MaterialTheme.typography.bodySmall)
            }
            SecondaryButton(stringResource(R.string.a_remove_cake), { dispatch(CakeIntent.AskRemove) }, Modifier.testTag(AdminTags.CAKE_FORM_REMOVE), enabled = !readOnly, destructive = true)
        }
    }
    CakeDialogs(state, dispatch, onBack)
    val toast = when (state.toast) {
        CakeToast.LAST_CAKE -> R.string.a_err_last_cake
        CakeToast.ERROR -> R.string.a_err_generic
        null -> null
    }
    AdminToast(toast?.let { stringResource(it) }, { dispatch(CakeIntent.ToastShown) }, HapticFeedbackType.Reject)
}

@Composable
private fun bannerText(banner: CakeBanner?): String? = when (banner) {
    CakeBanner.UPLOAD_FAILED -> stringResource(R.string.a_err_upload)
    CakeBanner.ERROR -> stringResource(R.string.a_err_generic)
    CakeBanner.OFFLINE -> stringResource(R.string.a_offline_save)
    CakeBanner.CAKES_FULL -> stringResource(R.string.a_err_cakes_full)
    null -> null
}
