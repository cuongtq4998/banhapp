package app.banh.customer.ui.launch

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.design.AppBackground
import app.banh.customer.design.LocalReduceMotion
import app.banh.customer.ui.common.LogoMark
import app.banh.customer.design.Motion
import app.banh.customer.design.Sizes
import kotlinx.coroutines.flow.Flow

private const val LOGO_START_SCALE = 0.85f
private const val LOGO_END_SCALE = 1f

/** S-1: the logo only. Nothing is tappable and no loading indicator is shown (UI document 5.1). */
@Composable
fun LaunchScreen(startWork: Flow<Load<*>>, onFinished: () -> Unit) {
    val reduceMotion = LocalReduceMotion.current
    val scale = remember { Animatable(if (reduceMotion) LOGO_END_SCALE else LOGO_START_SCALE) }
    val currentOnFinished by rememberUpdatedState(onFinished)

    LaunchedEffect(Unit) { scale.animateTo(LOGO_END_SCALE, tween(Motion.LONG_MILLIS)) }
    LaunchedEffect(startWork) {
        awaitLaunchExit(startWork)
        currentOnFinished()
    }

    AppBackground {
        LogoMark(
            size = Sizes.logoLarge,
            modifier = Modifier
                .align(Alignment.Center)
                .testTag(TestTags.LAUNCH_LOGO)
                .graphicsLayer {
                    scaleX = scale.value
                    scaleY = scale.value
                },
        )
    }
}
