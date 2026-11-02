package app.banh.admin.ui.cakes

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.cakes.CakeDone
import app.banh.admin.cakes.CakeFormViewModel
import app.banh.admin.cakes.CakeIntent
import app.banh.admin.cakes.initialCakeForm
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.ui.AdminTags
import app.banh.core.design.BanhScreen
import app.banh.core.design.StateMessage

/** Binds S-A8 to its view model. [cakeId] null adds a cake; a cake that is no longer in the settings (removed on another phone) shows `A_CAKE_GONE`. */
@Composable
fun CakeFormRoute(container: AdminContainer, store: SettingsViewModel, cakeId: String?, onBack: () -> Unit) {
    val settings = store.state.collectAsStateWithLifecycle().value.settings
    val cake = cakeId?.let { id -> settings?.cakes?.firstOrNull { it.cakeId == id } }
    val viewModel = viewModel<CakeFormViewModel>(
        key = "cake-${cakeId ?: "new"}",
        factory = viewModelFactory { initializer { CakeFormViewModel(initialCakeForm(cake, settings?.cakes.orEmpty()), container.owner, container.encoder, store) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val pick = container.photos.rememberPicker { uri -> uri?.let { viewModel.dispatch(CakeIntent.Pick(it)) } }
    LaunchedEffect(state.done) { if (state.done != CakeDone.NONE) onBack() }
    // Gone: the server said 404, or the reloaded settings no longer list the cake (and it is not this phone that just removed it).
    val vanished = cakeId != null && state.original != null && settings != null && state.done == CakeDone.NONE && settings.cakes.none { it.cakeId == cakeId }
    if (state.gone || vanished) {
        BanhScreen { _ ->
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                StateMessage(stringResource(R.string.a_cake_gone), stringResource(R.string.a_back_to_list), painterResource(R.drawable.ic_error), AdminTags.CAKE_FORM_GONE, AdminTags.CAKE_FORM_BACK_TO_LIST, onRetry = onBack)
            }
        }
    } else {
        CakeFormScreen(state, container.images, viewModel::dispatch, onBack, pick)
    }
}
