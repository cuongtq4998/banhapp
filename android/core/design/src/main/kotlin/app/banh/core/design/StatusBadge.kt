package app.banh.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** The four looks of a status badge; the word is always shown, colour is never the only signal (UI document 9). */
enum class BadgeTone(val fill: Color, val text: Color) {
    NEW(Color(StatusTokens.NEW_FILL), Color(StatusTokens.NEW_TEXT)),
    CONFIRMED(Color(StatusTokens.CONFIRMED_FILL), Color(StatusTokens.CONFIRMED_TEXT)),
    COMPLETED(Color(ColorTokens.TEXT_PRIMARY).copy(alpha = StatusTokens.COMPLETED_FILL_ALPHA), Color(StatusTokens.COMPLETED_TEXT)),
    CANCELLED(Color(StatusTokens.CANCELLED_FILL), Color(StatusTokens.CANCELLED_TEXT)),
}

@Composable
private fun badgeStyle() = MaterialTheme.typography.labelMedium.copy(fontSize = 12.sp, fontWeight = FontWeight.Bold)

/** `StatusBadge`: capsule with the status word. */
@Composable
fun StatusBadge(text: String, tone: BadgeTone, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = badgeStyle(),
        color = tone.text,
        modifier = modifier
            .defaultMinSize(minHeight = AdminSizes.badgeHeight)
            .background(tone.fill, CircleShape)
            .padding(horizontal = 10.dp, vertical = Spacing.xs),
    )
}

/** `DueMark`: red capsule with a clock icon and text ("Giao hôm nay", "Quá hạn 2 ngày"); never colour alone. */
@Composable
fun DueMarkChip(text: String, icon: Painter, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.background(Color(StatusTokens.DUE_FILL), CircleShape).padding(horizontal = 10.dp, vertical = Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Icon(painter = icon, contentDescription = null, tint = Color(StatusTokens.DUE_TEXT), modifier = Modifier.size(14.dp))
        Text(text, style = badgeStyle(), color = Color(StatusTokens.DUE_TEXT))
    }
}

/** `TabBadge` number: white on red, round. The caller hides it at 0 and passes "99+" above 99. */
@Composable
fun CountBadge(text: String, modifier: Modifier = Modifier) {
    Row(modifier = modifier.background(Color(StatusTokens.TAB_BADGE_FILL), CircleShape).defaultMinSize(minWidth = 20.dp, minHeight = 20.dp).padding(horizontal = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, style = badgeStyle(), color = Color(StatusTokens.TAB_BADGE_TEXT))
    }
}
