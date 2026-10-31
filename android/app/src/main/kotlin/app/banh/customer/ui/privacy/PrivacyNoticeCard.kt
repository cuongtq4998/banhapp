package app.banh.customer.ui.privacy

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.design.GlassCard
import app.banh.customer.design.Sizes
import app.banh.customer.design.Spacing
import app.banh.customer.design.bodyStrong

/**
 * Full privacy notice at the top of S-7 (FR-20, AC-30): always visible, not dismissible or collapsible, grows with the
 * text size. One traversal group read first; the title is a heading and the link is the only interactive element.
 */
@Composable
fun PrivacyNoticeCard(modifier: Modifier = Modifier) {
    val openPrivacy = rememberOpenPrivacy()
    GlassCard(modifier.fillMaxWidth().semantics { isTraversalGroup = true }.testTag(TestTags.ORDER_PRIVACY_CARD)) {
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(painterResource(R.drawable.ic_lock), contentDescription = null, modifier = Modifier.size(20.dp), tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(Spacing.sm))
                Text(
                    stringResource(R.string.privacy_title),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.semantics { heading() }.testTag(TestTags.ORDER_PRIVACY_TITLE),
                )
            }
            Text(stringResource(R.string.privacy_body), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.testTag(TestTags.ORDER_PRIVACY_BODY))
            Text(stringResource(R.string.privacy_draft), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.testTag(TestTags.ORDER_PRIVACY_DRAFT))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = Sizes.touchTarget)
                    .clickable(onClickLabel = stringResource(R.string.privacy_link_a11y_hint), role = Role.Button, onClick = openPrivacy)
                    .testTag(TestTags.ORDER_PRIVACY_LINK),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.privacy_link),
                    style = MaterialTheme.typography.bodyStrong,
                    color = MaterialTheme.colorScheme.primary,
                    textDecoration = TextDecoration.Underline,
                )
            }
        }
    }
}

/** S-8 reminder: the one-sentence notice and, below it, a text link to the full page; the link is off while sending. */
@Composable
fun ReviewPrivacyNotice(sending: Boolean, modifier: Modifier = Modifier) {
    val openPrivacy = rememberOpenPrivacy()
    Column(modifier) {
        Text(stringResource(R.string.review_privacy), style = MaterialTheme.typography.bodySmall, modifier = Modifier.testTag(TestTags.REVIEW_PRIVACY))
        Row(
            modifier = Modifier
                .heightIn(min = Sizes.touchTarget)
                .clickable(enabled = !sending, onClickLabel = stringResource(R.string.privacy_link_a11y_hint), role = Role.Button, onClick = openPrivacy)
                .testTag(TestTags.REVIEW_PRIVACY_LINK),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                stringResource(R.string.review_privacy_link),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.primary,
                textDecoration = TextDecoration.Underline,
            )
        }
    }
}
