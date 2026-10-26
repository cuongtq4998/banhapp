package app.banh.customer.ui.launch

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.testing.ContractAssets
import app.banh.customer.testing.setBanhContent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Rule
import org.junit.Test

/** S-1, Default (UI document 5.1). */
class LaunchScreenTest {
    @get:Rule
    val rule = createComposeRule()

    // TC-201, AC-1: the logo is shown, and the screen hands over to S-2 once the start work has settled.
    // The 1.0 s minimum and 2.0 s maximum are unit tested in LaunchDelayTest; the test clock here runs ahead of real time.
    @Test
    fun showsTheLogoAndHandsOverWhenTheStartWorkSettles() {
        var finished = 0
        val startWork = startWork(Load.Ready(ContractAssets.catalog()))
        rule.setBanhContent { LaunchScreen(startWork, onFinished = { finished++ }) }

        rule.onNodeWithTag(TestTags.LAUNCH_LOGO).assertIsDisplayed()
        rule.waitUntil(timeoutMillis = HAND_OVER_TIMEOUT_MILLIS) { finished == 1 }
    }

    // TC-165, AC-1: a start that never settles is cut off at the maximum time, and S-2 shows its own loading state.
    @Test
    fun handsOverEvenWhenTheStartWorkNeverSettles() {
        var finished = 0
        val startWork = startWork(Load.Loading)
        rule.setBanhContent { LaunchScreen(startWork, onFinished = { finished++ }) }

        rule.waitUntil(timeoutMillis = HAND_OVER_TIMEOUT_MILLIS) { finished == 1 }
    }

    // Built before the composition: a flow created inside it would be replaced on every recomposition and restart the wait.
    private fun startWork(state: Load<*>): Flow<Load<*>> = MutableStateFlow(state)

    private companion object {
        // Well above the 2.0 s maximum of the screen, so only a screen that never hands over fails.
        const val HAND_OVER_TIMEOUT_MILLIS = 10_000L
    }
}
