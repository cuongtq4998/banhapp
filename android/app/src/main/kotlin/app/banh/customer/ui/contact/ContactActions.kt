package app.banh.customer.ui.contact

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import app.banh.customer.R
import app.banh.customer.data.catalog.Shop
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** Opens Zalo or the dialer and tells the customer when that is not possible; shared by S-2 and S-9. */
@Stable
class ContactActions(
    private val launcher: ContactLauncher,
    private val scope: CoroutineScope,
    private val snackbarHostState: SnackbarHostState,
    private val zaloFailedText: String,
    private val phoneFailedText: String,
) {
    fun openZalo(shop: Shop) {
        if (!launcher.openZalo(shop.zaloContact)) announce(zaloFailedText)
    }

    fun openPhone(shop: Shop) {
        if (!launcher.openPhone(shop.phoneContact)) announce(phoneFailedText)
    }

    private fun announce(text: String) {
        scope.launch {
            snackbarHostState.currentSnackbarData?.dismiss()
            snackbarHostState.showSnackbar(text)
        }
    }
}

@Composable
fun rememberContactActions(snackbarHostState: SnackbarHostState): ContactActions {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val zaloFailed = stringResource(R.string.err_open_zalo)
    val phoneFailed = stringResource(R.string.err_open_phone)
    return remember(context, scope, snackbarHostState, zaloFailed, phoneFailed) {
        ContactActions(IntentContactLauncher(context), scope, snackbarHostState, zaloFailed, phoneFailed)
    }
}
