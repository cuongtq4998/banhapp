package app.banh.customer.ui.order

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.banh.customer.R
import app.banh.customer.TestTags
import app.banh.customer.data.Load
import app.banh.customer.data.map
import app.banh.customer.design.GlassCard
import app.banh.customer.design.PrimaryButton
import app.banh.customer.design.Spacing
import app.banh.customer.order.OrderEffect
import app.banh.customer.order.OrderFlowState
import app.banh.customer.order.OrderFlowViewModel
import app.banh.customer.order.OrderIntent
import app.banh.customer.order.RecipientError
import app.banh.customer.order.RecipientField
import app.banh.customer.ui.privacy.PrivacyNoticeCard
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

@StringRes
private fun RecipientError.messageRes(): Int = when (this) {
    RecipientError.NAME_REQUIRED -> R.string.err_name_required
    RecipientError.PHONE_REQUIRED -> R.string.err_phone_required
    RecipientError.PHONE_INVALID -> R.string.err_phone_invalid
    RecipientError.ADDRESS_REQUIRED -> R.string.err_address_required
    RecipientError.DISTRICT_REQUIRED -> R.string.err_district_required
}

@Composable
fun RecipientRoute(flow: OrderFlowViewModel, onBack: () -> Unit, onNext: () -> Unit) {
    val state by flow.state.collectAsStateWithLifecycle()
    val focusEvents = remember { MutableSharedFlow<RecipientField>(extraBufferCapacity = 1) }
    val currentOnNext by rememberUpdatedState(onNext)
    LaunchedEffect(flow) {
        flow.effects.collect { effect ->
            when (effect) {
                is OrderEffect.FocusField -> focusEvents.emit(effect.field)
                OrderEffect.GoToReview -> currentOnNext()
                // Meant for S-8; S-7 is not the one that sends.
                OrderEffect.GoToRecipient -> Unit
            }
        }
    }
    RecipientScreen(state, flow::onIntent, onBack, focusEvents.asSharedFlow())
}

/**
 * S-7, step 3: recipient, address, district and an optional note (FR-8, FR-18). Next checks every required field at
 * once; the store answers with an effect, either to go on or to focus the first failing field (AC-12).
 */
@Composable
fun RecipientScreen(
    state: OrderFlowState,
    onIntent: (OrderIntent) -> Unit,
    onBack: () -> Unit,
    focusEvents: Flow<RecipientField>,
) {
    val requesters = remember { RecipientField.entries.associateWith { FocusRequester() } }
    LaunchedEffect(focusEvents) {
        focusEvents.collect { field ->
            try {
                requesters.getValue(field).requestFocus()
            } catch (e: IllegalStateException) {
                // Nothing to focus yet, for example the district list is still loading.
            }
        }
    }
    val districts = state.catalog.map { it.districts }
    val noDistrictToChoose = (districts as? Load.Ready)?.value?.isEmpty() == true
    OrderStepScaffold(
        step = 3,
        onBack = onBack,
        bottomBar = {
            PrimaryButton(
                text = stringResource(R.string.common_next),
                onClick = { onIntent(OrderIntent.SubmitRecipient) },
                modifier = Modifier.testTag(TestTags.ORDER_NEXT),
                // Only an empty district list blocks Next; other mistakes are shown on tap (UI document 5.7).
                enabled = !noDistrictToChoose,
            )
        },
    ) {
        PrivacyNoticeCard()
        GlassCard(Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(Spacing.md)) {
                IdentityFields(state, onIntent, requesters)
                DistrictPicker(
                    districts = districts,
                    selectedId = state.draft.districtId,
                    errorText = state.recipientErrors[RecipientField.DISTRICT]?.let { stringResource(it.messageRes()) },
                    focusRequester = requesters.getValue(RecipientField.DISTRICT),
                    onSelect = { onIntent(OrderIntent.ChooseDistrict(it)) },
                    onRetry = { onIntent(OrderIntent.RetryCatalog) },
                )
            }
        }
        GlassCard(Modifier.fillMaxWidth()) { NoteField(state, onIntent) }
    }
}

@Composable
private fun IdentityFields(state: OrderFlowState, onIntent: (OrderIntent) -> Unit, requesters: Map<RecipientField, FocusRequester>) {
    fun messages(key: String, errorText: String?) = FieldMessages(errorText, TestTags.orderFieldError(key))
    val errors = state.recipientErrors
    FormTextField(
        value = state.draft.name,
        onValueChange = { onIntent(OrderIntent.EditName(it)) },
        label = stringResource(R.string.field_name),
        testTag = TestTags.ORDER_FIELD_NAME,
        focusRequester = requesters.getValue(RecipientField.NAME),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, keyboardType = KeyboardType.Text, imeAction = ImeAction.Next),
        messages = messages("name", errors[RecipientField.NAME]?.let { stringResource(it.messageRes()) }),
    )
    FormTextField(
        value = state.draft.phone,
        onValueChange = { onIntent(OrderIntent.EditPhone(it)) },
        label = stringResource(R.string.field_phone),
        testTag = TestTags.ORDER_FIELD_PHONE,
        focusRequester = requesters.getValue(RecipientField.PHONE),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
        messages = messages("phone", errors[RecipientField.PHONE]?.let { stringResource(it.messageRes()) }),
    )
    FormTextField(
        value = state.draft.address,
        onValueChange = { onIntent(OrderIntent.EditAddress(it)) },
        label = stringResource(R.string.field_address),
        testTag = TestTags.ORDER_FIELD_ADDRESS,
        focusRequester = requesters.getValue(RecipientField.ADDRESS),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text, imeAction = ImeAction.Next),
        messages = messages("address", errors[RecipientField.ADDRESS]?.let { stringResource(it.messageRes()) }),
        singleLine = false,
        minLines = ADDRESS_LINES,
    )
}

private const val ADDRESS_LINES = 2
