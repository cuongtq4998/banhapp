package app.banh.customer.ui.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.lifecycle.compose.LifecycleResumeEffect

/**
 * Asks for fresh data every time the screen comes to the front, also when the app returns from the background.
 * This is how a cake that the shop hid or made active again reaches a screen that is already open (BR-13, AC-33).
 */
@Composable
fun RefreshWhenResumed(onRefresh: () -> Unit) {
    val currentOnRefresh by rememberUpdatedState(onRefresh)
    LifecycleResumeEffect(Unit) {
        currentOnRefresh()
        onPauseOrDispose { }
    }
}
