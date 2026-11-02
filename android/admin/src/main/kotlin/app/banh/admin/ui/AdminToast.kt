package app.banh.admin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import app.banh.core.design.Radii
import app.banh.core.design.Spacing
import kotlinx.coroutines.delay

private const val TOAST_MILLIS = 3_000L

/** A short message at the top (`Toast`). It hides itself after 3 s by calling [onShown]; [haptic] fires once when it appears. */
@Composable
fun AdminToast(message: String?, onShown: () -> Unit, haptic: HapticFeedbackType? = HapticFeedbackType.Confirm) {
    if (message == null) return
    val feedback = LocalHapticFeedback.current
    LaunchedEffect(message) {
        haptic?.let { feedback.performHapticFeedback(it) }
        delay(TOAST_MILLIS)
        onShown()
    }
    Box(Modifier.fillMaxWidth().statusBarsPadding().padding(Spacing.lg), contentAlignment = Alignment.TopCenter) {
        Text(
            message,
            color = MaterialTheme.colorScheme.inverseOnSurface,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier
                .background(MaterialTheme.colorScheme.inverseSurface, RoundedCornerShape(Radii.image))
                .padding(Spacing.lg)
                .semantics { liveRegion = LiveRegionMode.Polite }
                .testTag(AdminTags.TOAST),
        )
    }
}
