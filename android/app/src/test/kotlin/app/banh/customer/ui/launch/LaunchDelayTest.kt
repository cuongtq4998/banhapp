package app.banh.customer.ui.launch

import app.banh.customer.data.Load
import app.banh.customer.data.LoadFailure
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LaunchDelayTest {
    private val minMillis = LAUNCH_MIN_DURATION.inWholeMilliseconds
    private val maxMillis = LAUNCH_MAX_DURATION.inWholeMilliseconds

    @Test
    fun fastStartStillShowsTheLogoForTheMinimumTime() = runTest {
        awaitLaunchExit(MutableStateFlow<Load<*>>(Load.Ready("catalog")))

        assertEquals(minMillis, currentTime)
    }

    @Test
    fun slowStartIsCutOffAtTheMaximumTime() = runTest {
        awaitLaunchExit(MutableStateFlow<Load<*>>(Load.Loading))

        assertEquals(maxMillis, currentTime)
    }

    @Test
    fun startThatSettlesBetweenTheLimitsEndsWhenItSettles() = runTest {
        val startWork = MutableStateFlow<Load<*>>(Load.Loading)
        val settleAfter = (minMillis + maxMillis) / 2
        launch {
            delay(settleAfter)
            startWork.value = Load.Failed(LoadFailure.NETWORK)
        }

        awaitLaunchExit(startWork)

        assertEquals(settleAfter, currentTime)
    }
}
