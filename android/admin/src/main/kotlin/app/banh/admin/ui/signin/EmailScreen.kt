package app.banh.admin.ui.signin

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import app.banh.admin.R
import app.banh.admin.auth.SessionState
import app.banh.admin.signin.SignInError
import app.banh.admin.signin.SignInIntent
import app.banh.admin.signin.SignInState
import app.banh.admin.ui.AdminTags
import app.banh.core.design.AppBackground
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.InfoMessageView
import app.banh.core.design.LogoBlob
import app.banh.core.design.PrimaryButton
import app.banh.core.design.Sizes
import app.banh.core.design.Spacing

/** S-A1: ask for the e-mail address. The same screen and next step whether or not the address is registered (FR-1, AC-1). */
@Composable
fun EmailScreen(state: SignInState, signedOut: SessionState.SignedOut, dispatch: (SignInIntent) -> Unit) {
    AppBackground {
        Column(
            modifier = Modifier.systemBarsPadding().imePadding().verticalScroll(rememberScrollState()).padding(Spacing.screenMargin),
            verticalArrangement = Arrangement.spacedBy(Spacing.lg),
            horizontalAlignment = Alignment.Start,
        ) {
            LogoBlob(size = Sizes.logoSmall, label = stringResource(R.string.app_name))
            Text(stringResource(R.string.a_signin_title), style = MaterialTheme.typography.headlineMedium)
            Banner(signedOut)
            Text(stringResource(R.string.a_signin_hint), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            val invalid = state.error == SignInError.EmailInvalid
            OutlinedTextField(
                value = state.email,
                onValueChange = { dispatch(SignInIntent.EmailChanged(it)) },
                label = { Text(stringResource(R.string.a_email_label)) },
                singleLine = true,
                enabled = !state.busy,
                isError = invalid,
                supportingText = if (invalid) ({ Text(stringResource(R.string.a_err_email_invalid), modifier = Modifier.testTag(AdminTags.SIGNIN_ERROR)) }) else null,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None, autoCorrectEnabled = false, keyboardType = KeyboardType.Email, imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { dispatch(SignInIntent.SendCode) }),
                modifier = Modifier.fillMaxWidth().testTag(AdminTags.SIGNIN_EMAIL),
            )
            RequestError(state.error)
            PrimaryButton(
                text = stringResource(R.string.a_send_code),
                onClick = { dispatch(SignInIntent.SendCode) },
                enabled = state.canSend,
                loading = state.busy,
                modifier = Modifier.testTag(AdminTags.SIGNIN_SEND),
            )
            Text(stringResource(R.string.a_session_note), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Banner(signedOut: SessionState.SignedOut) {
    val text = when {
        signedOut.ended -> R.string.a_session_ended
        signedOut.offline -> R.string.a_offline_signout
        else -> return
    }
    InfoMessageView(stringResource(text), painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.SIGNIN_BANNER))
}

@Composable
private fun RequestError(error: SignInError?) {
    val text = when (error) {
        is SignInError.RateLimited -> stringResource(R.string.a_err_rate_send, error.minutes)
        SignInError.Offline -> stringResource(R.string.a_offline_save)
        SignInError.Generic -> stringResource(R.string.a_err_generic)
        else -> return
    }
    ErrorMessageView(text, painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.SIGNIN_ERROR))
}
