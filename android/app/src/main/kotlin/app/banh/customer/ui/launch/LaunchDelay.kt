package app.banh.customer.ui.launch

import app.banh.customer.data.Load
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/** UI document 5.1: the logo shows for at least 1.0 s and at most 2.0 s (proposed values). */
val LAUNCH_MIN_DURATION: Duration = 1_000.milliseconds
val LAUNCH_MAX_DURATION: Duration = 2_000.milliseconds

/**
 * Returns when the start work has settled (data shown or failed) and the minimum time has passed,
 * but never later than the maximum. A slow start moves on to S-2, which has its own loading state.
 */
suspend fun awaitLaunchExit(
    startWork: Flow<Load<*>>,
    minDuration: Duration = LAUNCH_MIN_DURATION,
    maxDuration: Duration = LAUNCH_MAX_DURATION,
) {
    withTimeoutOrNull(maxDuration) {
        coroutineScope {
            launch { delay(minDuration) }
            startWork.first { it !is Load.Loading }
        }
    }
}
