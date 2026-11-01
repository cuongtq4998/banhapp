package app.banh.admin.signin

import app.banh.admin.testing.httpError
import app.banh.core.network.ErrorCodes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SignInReducerTest {
    private fun run(vararg intents: SignInIntent, from: SignInState = SignInState()) = intents.fold(from, ::reduceSignIn)

    @Test
    fun badFormatShowsTheMessageOnlyAfterTheFirstSend() {
        val typed = run(SignInIntent.EmailChanged("abc"))
        assertFalse(typed.triedEmail)
        assertEquals(null, typed.error)

        val sent = reduceSignIn(typed, SignInIntent.SendCode)
        assertEquals(SignInError.EmailInvalid, sent.error)
        assertFalse(sent.busy)
    }

    @Test
    fun validAddressStartsTheRequestAndTheAnswerMovesToTheCodeStep() {
        val busy = run(SignInIntent.EmailChanged(" a@example.com "), SignInIntent.SendCode)
        assertTrue(busy.busy)

        val code = reduceSignIn(busy, SignInIntent.CodeSent(30))
        assertEquals(SignInStep.CODE, code.step)
        assertEquals(30, code.resendSeconds)
        assertFalse(code.busy)
    }

    @Test
    fun codeAcceptsDigitsOnlyAndSubmitNeedsSix() {
        val pasted = run(SignInIntent.CodeChanged("12 34-56 78"))
        assertEquals("123456", pasted.code)
        assertTrue(pasted.canSubmit)
        assertFalse(run(SignInIntent.CodeChanged("12345")).canSubmit)
    }

    @Test
    fun wrongCodeClearsTheCellsAndShakesOnce() {
        val failed = run(SignInIntent.CodeChanged("123456"), SignInIntent.SubmitCode, SignInIntent.SignInFailed(SignInError.CodeWrong))
        assertEquals("", failed.code)
        assertEquals(1, failed.shakeKey)
        assertEquals(SignInError.CodeWrong, failed.error)
        assertFalse(failed.busy)
    }

    @Test
    fun resendIsBlockedDuringTheWaitAndTheTickCountsDown() {
        val waiting = SignInState(step = SignInStep.CODE, resendSeconds = 2)
        assertEquals(waiting, reduceSignIn(waiting, SignInIntent.Resend))
        val done = run(SignInIntent.Tick, SignInIntent.Tick, SignInIntent.Tick, from = waiting)
        assertEquals(0, done.resendSeconds)
        assertTrue(reduceSignIn(done, SignInIntent.Resend).busy)
    }

    @Test
    fun changeEmailKeepsTheAddress() {
        val back = run(SignInIntent.ChangeEmail, from = SignInState(step = SignInStep.CODE, email = "a@example.com", code = "12"))
        assertEquals(SignInStep.EMAIL, back.step)
        assertEquals("a@example.com", back.email)
        assertEquals("", back.code)
    }

    @Test
    fun resendWaitAnswerGoesOnToTheCodeStepWithTheWaitLeft() {
        val failure = httpError(429, ErrorCodes.CODE_RESEND_WAIT, retryAfter = 20).toRequestFailure()
        val next = reduceSignIn(SignInState(email = "a@example.com", busy = true), failure)
        assertEquals(SignInStep.CODE, next.step)
        assertEquals(20, next.resendSeconds)
    }

    @Test
    fun errorsMapToTheirMessages() {
        assertEquals(SignInError.RateLimited(30), (httpError(429, ErrorCodes.CODE_REQUEST_LIMIT, 1800).toRequestFailure()).error)
        assertEquals(SignInError.CodeExpired, httpError(422, ErrorCodes.CODE_EXPIRED).toSignInFailure())
        assertEquals(SignInError.CodeWrong, httpError(422, ErrorCodes.CODE_INVALID).toSignInFailure())
        assertEquals(SignInError.Offline, app.banh.admin.testing.offline().toSignInFailure())
    }
}
