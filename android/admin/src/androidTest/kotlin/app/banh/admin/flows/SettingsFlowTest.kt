package app.banh.admin.flows

import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import app.banh.admin.testing.withStub
import app.banh.admin.testing.signInOwner
import app.banh.admin.testing.tap
import app.banh.admin.testing.waitForTag
import app.banh.admin.ui.AdminTags
import org.junit.Rule
import org.junit.Test

/** S-A6: five rows with their values, the two sign-out buttons, and the e-mail of the account that the server now sends. */
class SettingsFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    @Test
    fun fiveRowsShowTheirCurrentValues() = withStub {
        rule.signInOwner()
        rule.onNodeWithTag(AdminTags.SETTINGS_ROW_SHOP).assertTextContains("Tiem Banh Mau", substring = true)
        rule.onNodeWithTag(AdminTags.SETTINGS_ROW_CAKES).assertTextContains("2/12", substring = true)
        rule.onNodeWithTag(AdminTags.SETTINGS_ROW_RULES).assertTextContains("60", substring = true)
        rule.onNodeWithTag(AdminTags.SETTINGS_ROW_DELIVERY).assertTextContains("1 quận/huyện, 1 khung giờ", substring = true)
        rule.onNodeWithTag(AdminTags.SETTINGS_ROW_STAFF).assertTextContains("1/30", substring = true)
    }

    @Test
    fun accountEmailIsAlwaysShown() = withStub {
        rule.signInOwner()
        rule.waitForTag(AdminTags.ACCOUNT_EMAIL).assertTextContains("owner@example.com")
    }

    @Test
    fun signOutAsksOnceThenShowsTheSignInScreen() = withStub {
        rule.signInOwner()
        rule.tap(AdminTags.SETTINGS_SIGN_OUT, scroll = true)
        rule.tap(AdminTags.SETTINGS_SIGN_OUT_YES)
        rule.waitForTag(AdminTags.SIGNIN_EMAIL)
    }
}
