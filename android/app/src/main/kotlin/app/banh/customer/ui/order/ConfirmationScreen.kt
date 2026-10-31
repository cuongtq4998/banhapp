package app.banh.customer.ui.order

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Shop
import app.banh.customer.design.BanhScreen
import app.banh.customer.design.BottomActionBar
import app.banh.customer.design.ContactButton
import app.banh.customer.design.GlassCard
import app.banh.customer.design.SecondaryButton
import app.banh.customer.design.Spacing
import app.banh.customer.order.OrderFlowViewModel
import app.banh.customer.order.OrderIntent
import app.banh.customer.order.SubmitState
import app.banh.customer.ui.contact.ContactActions
import app.banh.customer.ui.contact.rememberContactActions
import java.util.UUID

private val StatusMarkSize = 96.dp
private val StatusIconSize = 48.dp

/**
 * S-9 host: shows the code of the received order. Home clears the flow data and the key and leaves the graph
 * ([onHome]); the system back button does the same, so S-8 can never be reached again (UI document 5.9).
 */
@Composable
fun ConfirmationRoute(flow: OrderFlowViewModel, onHome: () -> Unit) {
    val state by flow.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val contactActions = rememberContactActions(snackbarHostState)
    // Kept, so the code stays on screen while the flow data is cleared on the way out.
    val code = remember { (state.submit as? SubmitState.Confirmed)?.orderCode }
    val shop = ((state.catalog as? Load.Ready)?.value)?.shop
    val currentOnHome by rememberUpdatedState(onHome)
    val goHome = {
        flow.onIntent(OrderIntent.FinishOrder(UUID.randomUUID().toString()))
        currentOnHome()
    }
    // No code (the process was restarted on this screen): there is nothing to show.
    LaunchedEffect(code) { if (code == null) goHome() }
    if (code != null) ConfirmationScreen(code, shop, contactActions, snackbarHostState, goHome)
}

@Composable
fun ConfirmationScreen(
    orderCode: String,
    shop: Shop?,
    contactActions: ContactActions,
    snackbarHostState: SnackbarHostState,
    onHome: () -> Unit,
) {
    BackHandler(onBack = onHome)
    BanhScreen(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            BottomActionBar {
                SecondaryButton(
                    text = stringResource(R.string.conf_btn_home),
                    onClick = onHome,
                    modifier = Modifier.testTag(TestTags.CONF_HOME),
                )
            }
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.screenMargin, vertical = Spacing.lg),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            StatusMark()
            Text(
                stringResource(R.string.conf_title),
                style = MaterialTheme.typography.headlineLarge,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() }.testTag(TestTags.CONF_TITLE),
            )
            CodeCard(orderCode)
            Text(
                stringResource(R.string.conf_message),
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
                modifier = Modifier.testTag(TestTags.CONF_MESSAGE),
            )
            ContactRow(enabled = shop != null, onZalo = { shop?.let(contactActions::openZalo) }, onPhone = { shop?.let(contactActions::openPhone) })
        }
    }
}

@Composable
private fun StatusMark() {
    Box(
        modifier = Modifier.size(StatusMarkSize).background(MaterialTheme.colorScheme.primaryContainer, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_check),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onPrimaryContainer,
            modifier = Modifier.size(StatusIconSize),
        )
    }
}

// The code is selectable text: press and hold copies it (UI document 5.9), there is no extra copy button.
@Composable
private fun CodeCard(orderCode: String) {
    val spoken = stringResource(R.string.conf_code_a11y, orderCode)
    GlassCard(Modifier.fillMaxWidth()) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            Text(stringResource(R.string.conf_code_label), style = MaterialTheme.typography.bodySmall)
            SelectionContainer {
                Text(
                    orderCode,
                    style = MaterialTheme.typography.headlineLarge,
                    modifier = Modifier.semantics { contentDescription = spoken }.testTag(TestTags.CONF_CODE),
                )
            }
        }
    }
}

@Composable
private fun ContactRow(enabled: Boolean, onZalo: () -> Unit, onPhone: () -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        ContactButton(
            text = stringResource(R.string.home_btn_zalo),
            icon = painterResource(R.drawable.ic_chat),
            onClick = onZalo,
            enabled = enabled,
            modifier = Modifier.weight(1f).testTag(TestTags.CONF_ZALO),
        )
        ContactButton(
            text = stringResource(R.string.home_btn_phone),
            icon = painterResource(R.drawable.ic_call),
            onClick = onPhone,
            enabled = enabled,
            modifier = Modifier.weight(1f).testTag(TestTags.CONF_PHONE),
        )
    }
}
