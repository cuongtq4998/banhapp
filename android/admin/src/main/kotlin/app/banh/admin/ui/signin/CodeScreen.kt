package app.banh.admin.ui.signin

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import app.banh.admin.R
import app.banh.admin.signin.SignInError
import app.banh.admin.signin.SignInIntent
import app.banh.admin.signin.SignInState
import app.banh.admin.ui.AdminTags
import app.banh.core.design.AppBackground
import app.banh.core.design.BackControl
import app.banh.core.design.BanhInlineTopBar
import app.banh.core.design.ErrorMessageView
import app.banh.core.design.OtpField
import app.banh.core.design.PrimaryButton
import app.banh.core.design.Spacing

/** S-A2: enter the 6-digit code. The sixth digit does not submit by itself (UI document S-A2). */
@Composable
fun CodeScreen(state: SignInState, dispatch: (SignInIntent) -> Unit) {
    AppBackground {
        Column(modifier = Modifier.systemBarsPadding().imePadding()) {
            BanhInlineTopBar(
                title = stringResource(R.string.a_code_title),
                back = BackControl(painterResource(R.drawable.ic_arrow_back), stringResource(R.string.a_back), AdminTags.NAV_BACK),
                onBack = { dispatch(SignInIntent.ChangeEmail) },
            )
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(Spacing.screenMargin),
                verticalArrangement = Arrangement.spacedBy(Spacing.lg),
            ) {
                Text(prompt(state.email.trim()), style = MaterialTheme.typography.bodyLarge)
                OtpField(
                    value = state.code,
                    onValueChange = { dispatch(SignInIntent.CodeChanged(it)) },
                    label = stringResource(R.string.a_code_field_a11y),
                    enabled = !state.busy,
                    isError = state.error is SignInError.CodeWrong || state.error is SignInError.CodeExpired,
                    shakeKey = state.shakeKey,
                    modifier = Modifier.testTag(AdminTags.CODE_FIELD),
                )
                CodeError(state.error)
                Resend(state, dispatch)
                TextButton(onClick = { dispatch(SignInIntent.ChangeEmail) }, modifier = Modifier.testTag(AdminTags.CODE_CHANGE_EMAIL)) {
                    Text(stringResource(R.string.a_change_email))
                }
                PrimaryButton(
                    text = stringResource(R.string.a_signin),
                    onClick = { dispatch(SignInIntent.SubmitCode) },
                    enabled = state.canSubmit,
                    loading = state.busy,
                    modifier = Modifier.testTag(AdminTags.CODE_SUBMIT),
                )
            }
        }
    }
}

// The address is bold inside the sentence (UI document S-A2).
@Composable
private fun prompt(email: String) = buildAnnotatedString {
    val sentence = stringResource(R.string.a_code_prompt, email)
    val start = sentence.indexOf(email)
    append(sentence.substring(0, start))
    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(email) }
    append(sentence.substring(start + email.length))
}

@Composable
private fun Resend(state: SignInState, dispatch: (SignInIntent) -> Unit) {
    if (state.resendSeconds > 0) {
        Text(
            stringResource(R.string.a_resend_wait, state.resendSeconds),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.testTag(AdminTags.CODE_RESEND),
        )
    } else {
        TextButton(onClick = { dispatch(SignInIntent.Resend) }, enabled = state.canResend, modifier = Modifier.testTag(AdminTags.CODE_RESEND)) {
            Text(stringResource(R.string.a_resend))
        }
    }
}

@Composable
private fun CodeError(error: SignInError?) {
    val text = when (error) {
        SignInError.CodeWrong -> stringResource(R.string.a_code_wrong)
        SignInError.CodeExpired -> stringResource(R.string.a_code_expired)
        is SignInError.RateLimited -> stringResource(R.string.a_err_rate_send, error.minutes)
        SignInError.Offline -> stringResource(R.string.a_offline_save)
        SignInError.Generic -> stringResource(R.string.a_err_generic)
        else -> return
    }
    ErrorMessageView(text, painterResource(R.drawable.ic_error), Modifier.testTag(AdminTags.CODE_ERROR))
}
