package app.banh.admin.flows

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import app.banh.admin.testing.has
import app.banh.admin.testing.launchStub
import app.banh.admin.testing.signIn
import app.banh.admin.testing.waitForTag
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class SignInFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    @Test
    fun sendIsDisabledUntilTheFieldHasTextAndABadAddressShowsTheMessage() {
        launchStub().use {
            rule.waitForTag(AdminTags.SIGNIN_SEND).assertIsNotEnabled()
            rule.onNodeWithTag(AdminTags.SIGNIN_EMAIL).performTextInput("not-an-email")
            rule.onNodeWithTag(AdminTags.SIGNIN_SEND).assertIsEnabled().performClick()
            rule.waitForTag(AdminTags.SIGNIN_ERROR)
        }
    }

    @Test
    fun wrongCodeThenCorrectCodeSignsInToTheList() {
        launchStub().use {
            rule.waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput("nhanvien.a@example.com")
            rule.onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
            rule.waitForTag(AdminTags.CODE_FIELD).performTextInput("000000")
            rule.onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
            rule.waitForTag(AdminTags.CODE_ERROR)
            rule.onNodeWithTag(AdminTags.CODE_SUBMIT).assertIsNotEnabled()

            rule.onNodeWithTag(AdminTags.CODE_FIELD).performTextInput("123456")
            rule.onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
            rule.waitForTag(AdminTags.ORDERS_LIST)
            assertFalse(rule.has(AdminTags.TAB_ORDERS))
        }
    }

    @Test
    fun expiredCodeAndTheRateLimitHaveTheirOwnMessages() {
        launchStub().use {
            rule.waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput("limit@example.com")
            rule.onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
            rule.waitForTag(AdminTags.SIGNIN_ERROR)
        }
        launchStub().use {
            rule.waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput("nhanvien.a@example.com")
            rule.onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
            rule.waitForTag(AdminTags.CODE_FIELD).performTextInput("999999")
            rule.onNodeWithTag(AdminTags.CODE_SUBMIT).performClick()
            rule.waitForTag(AdminTags.CODE_ERROR)
        }
    }

    @Test
    fun changeEmailGoesBackAndKeepsTheAddress() {
        launchStub().use {
            rule.waitForTag(AdminTags.SIGNIN_EMAIL).performTextInput("nhanvien.a@example.com")
            rule.onNodeWithTag(AdminTags.SIGNIN_SEND).performClick()
            rule.waitForTag(AdminTags.CODE_CHANGE_EMAIL).performClick()
            rule.waitForTag(AdminTags.SIGNIN_SEND).assertIsEnabled()
        }
    }

    @Test
    fun staffSignOutReturnsToTheEmailScreenWithNoOrdersLeft() {
        launchStub().use {
            rule.signIn()
            rule.onNodeWithTag(AdminTags.ORDERS_ACCOUNT).performClick()
            rule.waitForTag(AdminTags.ACCOUNT_SIGN_OUT).performClick()
            rule.waitForTag(AdminTags.ACCOUNT_SIGN_OUT_YES).performClick()
            rule.waitForTag(AdminTags.SIGNIN_EMAIL)
            assertTrue(!rule.has(AdminTags.ORDERS_LIST))
        }
    }
}
