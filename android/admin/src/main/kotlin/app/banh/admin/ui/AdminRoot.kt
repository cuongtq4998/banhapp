package app.banh.admin.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.auth.SessionState
import app.banh.admin.ui.signin.SignInRoute
import app.banh.core.design.AppBackground
import app.banh.core.design.BanhTheme
import app.banh.core.design.StateMessage
import kotlinx.coroutines.launch

/** Chooses what the person sees from the session alone: sign-in, the app, or a wait while the stored session is renewed. */
@Composable
fun AdminRoot(container: AdminContainer) {
    BanhTheme {
        val state by container.session.state.collectAsStateWithLifecycle()
        when (val current = state) {
            SessionState.Restoring -> AppBackground { Box(Modifier.fillMaxSize().testTag(AdminTags.ROOT_LOADING), Alignment.Center) { CircularProgressIndicator() } }
            SessionState.RestoreFailed -> RestoreFailed(container)
            is SessionState.SignedOut -> SessionScope("out-${container.signInPeriod}") { SignInRoute(container, current) }
            is SessionState.SignedIn -> {
                container.signInPeriod = current.id
                SessionScope("in-${current.id}") { SignedInRoot(container, current) }
            }
        }
    }
}

@Composable
private fun RestoreFailed(container: AdminContainer) {
    val scope = rememberCoroutineScope()
    AppBackground {
        Box(Modifier.fillMaxSize(), Alignment.Center) {
            StateMessage(
                message = stringResource(R.string.a_offline),
                retryLabel = stringResource(R.string.a_retry),
                icon = painterResource(R.drawable.ic_error),
                stateTag = AdminTags.ORDERS_OFFLINE,
                retryTag = AdminTags.ROOT_RETRY,
                onRetry = { scope.launch { container.session.restore() } },
            )
        }
    }
}
