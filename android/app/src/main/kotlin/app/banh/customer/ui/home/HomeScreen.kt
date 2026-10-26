package app.banh.customer.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.testTag
import app.banh.customer.TestTags
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.data.Load
import app.banh.customer.data.catalog.Shop
import app.banh.customer.design.BanhScreen
import app.banh.customer.design.BottomActionBar
import app.banh.customer.design.ContactButton
import app.banh.customer.design.ErrorState
import app.banh.customer.design.GlassCard
import app.banh.customer.design.InfoMessage
import app.banh.customer.design.LogoMark
import app.banh.customer.design.PrimaryButton
import app.banh.customer.design.SecondaryButton
import app.banh.customer.design.Sizes
import app.banh.customer.design.SkeletonBlock
import app.banh.customer.design.Spacing
import app.banh.customer.design.loadingSemantics
import app.banh.customer.ui.common.RefreshWhenResumed
import app.banh.customer.ui.contact.ContactActions
import app.banh.customer.ui.contact.rememberContactActions

private const val GREETING_SKELETON_LINES = 2
private val NameSkeletonWidth = 160.dp
private val NameSkeletonHeight = 32.dp
private val GreetingSkeletonHeight = 20.dp

@Composable
fun HomeRoute(viewModel: HomeViewModel, onViewProducts: () -> Unit, onPlaceOrder: () -> Unit) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    RefreshWhenResumed(onRefresh = viewModel::retry)
    val snackbarHostState = remember { SnackbarHostState() }
    HomeScreen(
        state = state,
        snackbarHostState = snackbarHostState,
        contactActions = rememberContactActions(snackbarHostState),
        onRetry = viewModel::retry,
        onViewProducts = onViewProducts,
        onPlaceOrder = onPlaceOrder,
    )
}

/** S-2. Every button is disabled until the shop data is shown (UI document 5.2). */
@Composable
fun HomeScreen(
    state: Load<HomeContent>,
    snackbarHostState: SnackbarHostState,
    contactActions: ContactActions,
    onRetry: () -> Unit,
    onViewProducts: () -> Unit,
    onPlaceOrder: () -> Unit,
) {
    val content = (state as? Load.Ready)?.value
    val shop = content?.shop
    val enabled = shop != null
    // Place order alone waits for a cake; the other buttons keep working with an empty shelf (UI document 5.2).
    val canPlaceOrder = content?.hasActiveCakes == true
    BanhScreen(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        bottomBar = {
            BottomActionBar {
                PrimaryButton(
                    stringResource(R.string.home_btn_order),
                    onClick = onPlaceOrder,
                    enabled = canPlaceOrder,
                    modifier = Modifier.testTag(TestTags.HOME_ORDER),
                )
                SecondaryButton(
                    stringResource(R.string.home_btn_products),
                    onClick = onViewProducts,
                    enabled = enabled,
                    modifier = Modifier.testTag(TestTags.HOME_PRODUCTS),
                )
            }
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(innerPadding)
                .padding(horizontal = Spacing.screenMargin, vertical = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            when (state) {
                is Load.Ready -> ShopHeader(state.value.shop)
                Load.Loading -> ShopHeaderSkeleton()
                is Load.Failed -> ErrorState(stringResource(R.string.home_err), onRetry)
            }
            ContactRow(
                enabled = enabled,
                onZalo = { shop?.let(contactActions::openZalo) },
                onPhone = { shop?.let(contactActions::openPhone) },
            )
            if (content != null && !content.hasActiveCakes) {
                InfoMessage(stringResource(R.string.home_no_cakes), Modifier.testTag(TestTags.HOME_NO_CAKES_NOTICE))
            }
        }
    }
}

@Composable
private fun ShopHeader(shop: Shop) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
        LogoMark(Sizes.logoSmall)
        Text(
            shop.name,
            style = MaterialTheme.typography.headlineLarge,
            modifier = Modifier.testTag(TestTags.HOME_SHOP_NAME).semantics { heading() },
        )
    }
    GlassCard(Modifier.fillMaxWidth()) {
        Text(shop.greeting, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.testTag(TestTags.HOME_GREETING))
    }
}

@Composable
private fun ShopHeaderSkeleton() {
    Column(Modifier.testTag(TestTags.HOME_SKELETON).loadingSemantics(), verticalArrangement = Arrangement.spacedBy(Spacing.lg)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Spacing.md)) {
            LogoMark(Sizes.logoSmall)
            SkeletonBlock(Modifier.width(NameSkeletonWidth).height(NameSkeletonHeight))
        }
        GlassCard(Modifier.fillMaxWidth()) {
            repeat(GREETING_SKELETON_LINES) {
                SkeletonBlock(Modifier.fillMaxWidth().height(GreetingSkeletonHeight).padding(vertical = Spacing.xs))
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
            modifier = Modifier.weight(1f).testTag(TestTags.HOME_ZALO),
        )
        ContactButton(
            text = stringResource(R.string.home_btn_phone),
            icon = painterResource(R.drawable.ic_call),
            onClick = onPhone,
            enabled = enabled,
            modifier = Modifier.weight(1f).testTag(TestTags.HOME_PHONE),
        )
    }
}
