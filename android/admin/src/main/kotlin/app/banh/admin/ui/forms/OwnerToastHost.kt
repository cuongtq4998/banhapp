package app.banh.admin.ui.forms

import androidx.compose.runtime.Composable
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.res.stringResource
import app.banh.admin.R
import app.banh.admin.owner.OwnerToast
import app.banh.admin.ui.AdminToast

/** Shows the toast a closed form left in the shared store ("Đã lưu", "Đã thêm bánh", ...), then clears it. */
@Composable
fun OwnerToastHost(toast: OwnerToast?, onShown: () -> Unit) {
    val text = when (toast) {
        OwnerToast.SAVED -> R.string.a_saved
        OwnerToast.CAKE_ADDED -> R.string.a_cake_added
        OwnerToast.CAKE_REMOVED -> R.string.a_cake_removed
        OwnerToast.STAFF_ADDED -> R.string.a_staff_added
        OwnerToast.ERR_GENERIC -> R.string.a_err_generic
        OwnerToast.OFFLINE_SAVE -> R.string.a_offline_save
        null -> null
    }
    val failure = toast == OwnerToast.ERR_GENERIC || toast == OwnerToast.OFFLINE_SAVE
    AdminToast(text?.let { stringResource(it) }, onShown, if (failure) HapticFeedbackType.Reject else HapticFeedbackType.Confirm)
}
