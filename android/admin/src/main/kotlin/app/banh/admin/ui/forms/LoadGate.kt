package app.banh.admin.ui.forms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import app.banh.admin.R
import app.banh.admin.owner.LoadPhase
import app.banh.admin.ui.AdminTags
import app.banh.core.design.SkeletonBlock
import app.banh.core.design.Spacing
import app.banh.core.design.StateMessage

/** Loading, Error and Offline of every settings screen (form rules): a skeleton, or a message with retry; [content] only when [phase] is ready. */
@Composable
fun LoadGate(phase: LoadPhase, onRetry: () -> Unit, content: @Composable () -> Unit) {
    when (phase) {
        LoadPhase.READY -> content()
        LoadPhase.LOADING -> Column(Modifier.fillMaxSize().padding(Spacing.screenMargin).testTag(AdminTags.OWNER_SKELETON), verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
            repeat(SKELETONS) { SkeletonBlock(Modifier.fillMaxWidth().height(96.dp)) }
        }
        LoadPhase.ERROR, LoadPhase.OFFLINE -> Box(Modifier.fillMaxSize().padding(Spacing.screenMargin), Alignment.Center) {
            val offline = phase == LoadPhase.OFFLINE
            StateMessage(
                message = stringResource(if (offline) R.string.a_offline else R.string.a_err_generic),
                retryLabel = stringResource(R.string.a_retry),
                icon = painterResource(R.drawable.ic_error),
                stateTag = if (offline) AdminTags.OWNER_OFFLINE else AdminTags.OWNER_ERROR,
                retryTag = AdminTags.OWNER_RETRY,
                onRetry = onRetry,
            )
        }
    }
}

private const val SKELETONS = 3

/** A page of the owner area that is not a form yet: top bar with back, and the load states until [ready] can be shown. */
@Composable
fun GatedPage(title: String, onBack: () -> Unit, phase: LoadPhase, onRetry: () -> Unit, ready: @Composable () -> Unit) {
    if (phase == LoadPhase.READY) {
        ready()
        return
    }
    androidx.activity.compose.BackHandler(onBack = onBack)
    app.banh.core.design.BanhScreen(
        topBar = { app.banh.core.design.BanhInlineTopBar(title, app.banh.core.design.BackControl(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.a_back), AdminTags.NAV_BACK), onBack) },
    ) { padding -> Box(Modifier.padding(padding)) { LoadGate(phase, onRetry) {} } }
}
