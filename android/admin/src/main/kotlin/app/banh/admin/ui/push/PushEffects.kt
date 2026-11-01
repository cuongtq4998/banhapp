package app.banh.admin.ui.push

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.admin.AdminContainer
import app.banh.admin.R
import app.banh.admin.push.PushMessage
import app.banh.admin.push.PushStep
import app.banh.admin.push.RUNTIME_PERMISSION_SDK
import app.banh.admin.push.decidePush
import app.banh.admin.ui.AdminTags
import app.banh.core.design.Radii
import app.banh.core.design.Spacing
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val FOREGROUND_TOAST_MILLIS = 4_000L

/**
 * Everything push does in the signed-in app (FR-25, FR-26, design part 7): the permission question and token registration right after
 * sign-in, the in-app toast for an order that arrives while the app is open, and the order a notification tap asks for.
 */
@Composable
fun PushEffects(container: AdminContainer, signedInId: Long, onOpenOrder: (String) -> Unit) {
    val hub = container.push
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> if (granted) scope.launch { hub.register() } }

    LaunchedEffect(signedInId) {
        val granted = Build.VERSION.SDK_INT < RUNTIME_PERMISSION_SDK || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        when (decidePush(hub.provider.available, granted, hub.askedFlag.asked)) {
            // One system question, once per phone, without a card of our own; a "no" is final and silent (AC-42).
            PushStep.ASK -> {
                hub.askedFlag.asked = true
                launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            PushStep.REGISTER -> hub.register()
            PushStep.NOTHING -> Unit
        }
    }

    val requested by hub.requestedOrder.collectAsStateWithLifecycle()
    LaunchedEffect(requested) {
        requested?.let {
            hub.orderOpened()
            onOpenOrder(it)
        }
    }

    var incoming by remember { mutableStateOf<PushMessage?>(null) }
    LaunchedEffect(Unit) {
        hub.foregroundMessages.collect {
            incoming = it
            container.orderChanges.notifyChanged()
        }
    }
    incoming?.let { message ->
        ForegroundToast(message, onTap = { incoming = null; onOpenOrder(message.orderCode) }, onShown = { incoming = null })
    }
}

/** `A_NOTIF_FOREGROUND` at the top for 4 s; a tap opens the order (the list behind it has already been told to reload). */
@Composable
private fun ForegroundToast(message: PushMessage, onTap: () -> Unit, onShown: () -> Unit) {
    val feedback = LocalHapticFeedback.current
    LaunchedEffect(message) {
        feedback.performHapticFeedback(HapticFeedbackType.ContextClick)
        delay(FOREGROUND_TOAST_MILLIS)
        onShown()
    }
    Box(Modifier.fillMaxWidth().statusBarsPadding().padding(Spacing.lg), contentAlignment = Alignment.TopCenter) {
        Text(
            stringResource(R.string.a_notif_foreground, message.orderCode),
            color = MaterialTheme.colorScheme.inverseOnSurface,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier
                .background(MaterialTheme.colorScheme.inverseSurface, RoundedCornerShape(Radii.image))
                .clickable(onClick = onTap)
                .padding(Spacing.lg)
                .semantics { liveRegion = LiveRegionMode.Polite }
                .testTag(AdminTags.TOAST),
        )
    }
}
