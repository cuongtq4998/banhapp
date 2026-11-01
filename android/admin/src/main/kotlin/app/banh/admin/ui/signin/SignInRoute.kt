package app.banh.admin.ui.signin

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import app.banh.admin.AdminContainer
import app.banh.admin.auth.SessionState
import app.banh.admin.signin.SignInIntent
import app.banh.admin.signin.SignInStep
import app.banh.admin.signin.SignInViewModel

/** S-A1 and S-A2 share one store, so "change e-mail" keeps what was typed (AC-3). */
@Composable
fun SignInRoute(container: AdminContainer, signedOut: SessionState.SignedOut) {
    val viewModel = viewModel<SignInViewModel>(factory = viewModelFactory { initializer { SignInViewModel(container.auth, container.session) } })
    val state by viewModel.state.collectAsStateWithLifecycle()
    when (state.step) {
        SignInStep.EMAIL -> EmailScreen(state, signedOut, viewModel::dispatch)
        SignInStep.CODE -> {
            BackHandler { viewModel.dispatch(SignInIntent.ChangeEmail) }
            CodeScreen(state, viewModel::dispatch)
        }
    }
}
