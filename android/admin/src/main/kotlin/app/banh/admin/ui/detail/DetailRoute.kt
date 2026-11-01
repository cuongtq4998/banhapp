package app.banh.admin.ui.detail

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.orderdetail.OrderDetailViewModel

@Composable
fun DetailRoute(container: AdminContainer, orderCode: String, onBack: () -> Unit) {
    val viewModel = viewModel<OrderDetailViewModel>(
        key = "detail-$orderCode",
        factory = viewModelFactory { initializer { OrderDetailViewModel(orderCode, container.orders, container.orderChanges) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    OrderDetailScreen(
        state = state,
        serverDate = container.serverDate.get(),
        dispatch = viewModel::dispatch,
        onBack = onBack,
        onCall = { phone -> start(context, Intent(Intent.ACTION_DIAL, Uri.parse("tel:$phone")), null) },
        // ADR-0015: the web link opens the Zalo app when it is installed, else the browser. No permission, no custom scheme.
        onZalo = { phone -> start(context, Intent(Intent.ACTION_VIEW, Uri.parse("https://zalo.me/${phone.removePrefix("+")}")), R.string.a_zalo_unavailable) },
    )
}

private fun start(context: Context, intent: Intent, failureText: Int?) {
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        failureText?.let { Toast.makeText(context, it, Toast.LENGTH_SHORT).show() }
    }
}
