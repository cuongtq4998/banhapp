package app.banh.customer.ui.common

import androidx.annotation.StringRes
import app.banh.customer.R
import app.banh.customer.data.LoadFailure

/** Message of a failed catalog load on S-3 to S-5: the network message offline, the screen's own message otherwise (UI document 5.10). */
@StringRes
fun catalogLoadFailureText(failure: LoadFailure): Int = when (failure) {
    LoadFailure.NETWORK -> R.string.err_network_load
    LoadFailure.OTHER -> R.string.products_err
}
