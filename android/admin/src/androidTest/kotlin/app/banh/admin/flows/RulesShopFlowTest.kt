package app.banh.admin.flows

import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import app.banh.admin.testing.has
import app.banh.admin.testing.openArea
import app.banh.admin.testing.signInOwner
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.testing.withStub
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/** S-A9 (ordering rules with the impact preview) and S-A11 (shop info) against the stub. */
class RulesShopFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun openRules() {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_RULES)
        rule.waitForTag(AdminTags.RULES_LIMIT)
    }

    @Test
    fun saveIsOffUntilSomethingChanges() = withStub {
        openRules()
        rule.onNodeWithTag(AdminTags.RULES_SAVE).assertIsNotEnabled()
    }

    @Test
    fun aLowerLimitAsksWhichDatesAreAffectedBeforeSaving() = withStub {
        openRules()
        rule.typeInto(AdminTags.RULES_LIMIT, "40")
        rule.tap(AdminTags.RULES_SAVE)
        rule.waitForTag(AdminTags.RULES_WARN_DIALOG)
        rule.tap(AdminTags.RULES_WARN_CONFIRM)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitForTag(AdminTags.SETTINGS_ROW_RULES)
        assertFalse(rule.has(AdminTags.RULES_WARN_DIALOG))
    }

    @Test
    fun backOnTheWarningChangesNothing() = withStub {
        openRules()
        rule.typeInto(AdminTags.RULES_LIMIT, "40")
        rule.tap(AdminTags.RULES_SAVE)
        rule.waitForTag(AdminTags.RULES_WARN_DIALOG)
        rule.tap(AdminTags.RULES_WARN_BACK)
        rule.waitUntilGone(AdminTags.RULES_WARN_DIALOG)
        assertTrue(rule.has(AdminTags.RULES_SAVE))
    }

    @Test
    fun aRaisedLimitSavesWithoutAWarning() = withStub {
        openRules()
        rule.typeInto(AdminTags.RULES_LIMIT, "80")
        rule.tap(AdminTags.RULES_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        assertFalse(rule.has(AdminTags.RULES_WARN_DIALOG))
    }

    @Test
    fun everyBadFieldIsListedAtOnceAndMinAboveLimitHasItsOwnMessage() = withStub {
        openRules()
        rule.typeInto(AdminTags.RULES_LIMIT, "10")
        rule.typeInto(AdminTags.RULES_MIN, "15")
        rule.typeInto(AdminTags.RULES_LEAD, "20")
        rule.tap(AdminTags.RULES_SAVE)
        rule.waitForTag(AdminTags.rulesError("min"))
        rule.waitForTag(AdminTags.rulesError("lead"))
    }

    @Test
    fun shopSavesAndNamesEachInvalidField() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_SHOP)
        rule.typeInto(AdminTags.SHOP_NAME, "")
        rule.typeInto(AdminTags.SHOP_PHONE, "abc")
        rule.typeInto(AdminTags.SHOP_ZALO, "ab")
        rule.tap(AdminTags.SHOP_SAVE)
        rule.waitForTag(AdminTags.shopError("name"))
        rule.waitForTag(AdminTags.shopError("phone"))
        rule.waitForTag(AdminTags.shopError("zalo"))
        rule.typeInto(AdminTags.SHOP_NAME, "Tiem Moi")
        rule.typeInto(AdminTags.SHOP_PHONE, "0912 345 678")
        rule.typeInto(AdminTags.SHOP_ZALO, "zalo.me/tiemmoi")
        rule.tap(AdminTags.SHOP_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitForTag(AdminTags.SETTINGS_ROW_SHOP)
    }

    @Test
    fun aServerRefusalOfTheShopShowsFieldMessagesAndKeepsTheForm() = withStub {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_SHOP)
        rule.typeInto(AdminTags.SHOP_NAME, "invalid shop")
        rule.tap(AdminTags.SHOP_SAVE)
        rule.waitForTag(AdminTags.shopError("name"))
        assertTrue(rule.has(AdminTags.SHOP_SAVE))
    }
}
