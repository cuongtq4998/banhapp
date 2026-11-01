package app.banh.core.design

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

const val OTP_LENGTH = 6
private const val SHAKE_DP = 4f
private const val SHAKE_MILLIS = 60

/** Keeps digits only and at most six of them, so a paste of "123 456" fills all cells (UI document S-A2). */
fun sanitizeOtp(raw: String): String = raw.filter { it in '0'..'9' }.take(OTP_LENGTH)

/**
 * `OtpField`: six visible cells over one hidden text input. The input is the only element the screen reader sees
 * ([label]); the cells are hidden from it. [shakeKey] changes on each wrong code and moves the cells 4 dp once, unless motion is reduced.
 */
@Composable
fun OtpField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    isError: Boolean = false,
    shakeKey: Int = 0,
    requestFocus: Boolean = true,
) {
    val focus = remember { FocusRequester() }
    val shake = remember { Animatable(0f) }
    val reduceMotion = LocalReduceMotion.current
    LaunchedEffect(Unit) { if (requestFocus) focus.requestFocus() }
    LaunchedEffect(shakeKey) {
        if (shakeKey == 0 || reduceMotion) return@LaunchedEffect
        shake.animateTo(SHAKE_DP, tween(SHAKE_MILLIS))
        shake.animateTo(-SHAKE_DP, tween(SHAKE_MILLIS))
        shake.animateTo(0f, tween(SHAKE_MILLIS))
    }
    BasicTextField(
        value = value,
        onValueChange = { onValueChange(sanitizeOtp(it)) },
        enabled = enabled,
        modifier = modifier.focusRequester(focus).semantics { contentDescription = label },
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        cursorBrush = SolidColor(Color.Transparent),
        decorationBox = { Cells(value, isError, Modifier.offset(x = shake.value.dp)) },
    )
}

@Composable
private fun Cells(value: String, isError: Boolean, modifier: Modifier) {
    val borderColor = if (isError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.outline
    Row(modifier = modifier.clearAndSetSemantics {}, horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        repeat(OTP_LENGTH) { index ->
            Box(
                modifier = Modifier
                    .size(AdminSizes.otpCellWidth, AdminSizes.otpCellHeight)
                    .border(BorderStroke(if (isError) 2.dp else 1.dp, borderColor), RoundedCornerShape(16.dp))
                    .testTag("otp.cell.$index"),
                contentAlignment = Alignment.Center,
            ) {
                Text(value.getOrNull(index)?.toString().orEmpty(), style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
            }
        }
    }
}
