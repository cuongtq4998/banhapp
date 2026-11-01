package app.banh.admin.flows

import android.graphics.BitmapFactory
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import app.banh.admin.stub.StubUploads
import app.banh.admin.testing.has
import app.banh.admin.testing.withStub
import app.banh.admin.testing.openArea
import app.banh.admin.testing.signInOwner
import app.banh.admin.testing.tap
import app.banh.admin.testing.typeInto
import app.banh.admin.testing.waitForTag
import app.banh.admin.testing.waitUntilGone
import app.banh.admin.ui.AdminTags
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

private const val FIXTURE_CAKE = "5b0c2f6a-0000-4a00-8000-0000000000c1"
private const val HIDDEN_CAKE = "5b0c2f6a-0000-4a00-8000-0000000000c3"

/** S-A7 and S-A8 against the stub: add with a picture, validation, name taken, the 12-cake limit, hide, remove (api/07 10.17). */
class CakeFlowTest {
    @get:Rule val rule = createEmptyComposeRule()

    private fun openCakes() {
        rule.signInOwner()
        rule.openArea(AdminTags.SETTINGS_ROW_CAKES)
        rule.waitForTag(AdminTags.CAKES_ADD)
    }

    private fun fillCake(name: String) {
        rule.typeInto(AdminTags.CAKE_FORM_NAME, name)
        rule.typeInto(AdminTags.CAKE_FORM_DESC, "Banh ngon")
        rule.typeInto(AdminTags.CAKE_FORM_PRICE, "150000")
    }

    @Test
    fun listShowsActiveBeforeHiddenWithTheCount() = withStub {
        openCakes()
        rule.waitForTag(AdminTags.cakeRow(FIXTURE_CAKE))
        rule.waitForTag(AdminTags.cakeRow(HIDDEN_CAKE))
        rule.waitForTag(AdminTags.CAKES_COUNT)
    }

    @Test
    fun addWithPictureUploadsAJpegWithinTheLimitsThenShowsTheToastAndTheNewCake() = withStub {
        openCakes()
        StubUploads.last = null
        rule.tap(AdminTags.CAKES_ADD)
        rule.tap(AdminTags.CAKE_FORM_IMAGE)
        rule.waitForTag(AdminTags.CAKE_FORM_CHANGE)
        fillCake("Banh Mau Moi")
        rule.tap(AdminTags.CAKE_FORM_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitForTag(AdminTags.CAKES_ADD)
        val sent = StubUploads.last
        assertNotNull(sent)
        // ADR-0025: a JPEG (signature FF D8), at most 5,242,880 bytes, each side 200 to 4096 pixels.
        assertEquals(0xFF.toByte(), sent!![0])
        assertEquals(0xD8.toByte(), sent[1])
        assertTrue(sent.size <= 5_242_880)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(sent, 0, sent.size, bounds)
        assertTrue(bounds.outWidth in 200..4096 && bounds.outHeight in 200..4096)
        assertEquals("image/jpeg", bounds.outMimeType)
    }

    @Test
    fun savingAnEmptyFormListsEveryMissingFieldAtOnce() = withStub {
        openCakes()
        rule.tap(AdminTags.CAKES_ADD)
        rule.typeInto(AdminTags.CAKE_FORM_NAME, "x")
        rule.typeInto(AdminTags.CAKE_FORM_NAME, "")
        rule.typeInto(AdminTags.CAKE_FORM_PRICE, "5")
        rule.typeInto(AdminTags.CAKE_FORM_PRICE, "")
        rule.typeInto(AdminTags.CAKE_FORM_DESC, "d")
        rule.tap(AdminTags.CAKE_FORM_SAVE)
        rule.waitForTag(AdminTags.cakeFormError("name"))
        rule.waitForTag(AdminTags.cakeFormError("price"))
        rule.waitForTag(AdminTags.cakeFormError("image"))
    }

    @Test
    fun aNameInUseIsRefusedWithTheFieldMessage() = withStub {
        openCakes()
        rule.tap(AdminTags.CAKES_ADD)
        rule.tap(AdminTags.CAKE_FORM_IMAGE)
        rule.waitForTag(AdminTags.CAKE_FORM_CHANGE)
        fillCake("banh mau")
        rule.tap(AdminTags.CAKE_FORM_SAVE)
        rule.waitForTag(AdminTags.cakeFormError("name"))
        assertTrue(rule.has(AdminTags.CAKE_FORM_SAVE))
    }

    @Test
    fun theThirteenthCakeShowsTheFullMessageAndKeepsTheForm() = withStub {
        openCakes()
        rule.tap(AdminTags.CAKES_ADD)
        rule.tap(AdminTags.CAKE_FORM_IMAGE)
        rule.waitForTag(AdminTags.CAKE_FORM_CHANGE)
        fillCake("Full Cake")
        rule.tap(AdminTags.CAKE_FORM_SAVE)
        rule.waitForTag(AdminTags.OWNER_SAVE_ERROR)
        assertTrue(rule.has(AdminTags.CAKE_FORM_NAME))
    }

    @Test
    fun uploadCanBeStoppedAndNothingIsCreated() = withStub {
        openCakes()
        rule.tap(AdminTags.CAKES_ADD)
        rule.tap(AdminTags.CAKE_FORM_IMAGE)
        rule.waitForTag(AdminTags.CAKE_FORM_CHANGE)
        fillCake("Slow Cake")
        rule.tap(AdminTags.CAKE_FORM_SAVE)
        rule.waitForTag(AdminTags.CAKE_FORM_PROGRESS)
        rule.tap(AdminTags.CAKE_FORM_CANCEL)
        rule.waitUntilGone(AdminTags.CAKE_FORM_PROGRESS)
        assertTrue(rule.has(AdminTags.CAKE_FORM_NAME))
        assertFalse(rule.has(AdminTags.TOAST))
    }

    @Test
    fun hidingTheOnlyActiveCakeIsRefusedAtOnce() = withStub {
        openCakes()
        rule.tap(AdminTags.cakeRow(FIXTURE_CAKE))
        rule.tap(AdminTags.CAKE_FORM_ACTIVE, scroll = true)
        rule.waitForTag(AdminTags.TOAST)
        rule.onNodeWithTag(AdminTags.CAKE_FORM_SAVE).assertIsNotEnabled()
    }

    @Test
    fun removeAsksForConfirmationThenLeavesTheList() = withStub {
        openCakes()
        rule.tap(AdminTags.cakeRow(HIDDEN_CAKE))
        rule.tap(AdminTags.CAKE_FORM_REMOVE, scroll = true)
        rule.tap(AdminTags.CAKE_FORM_REMOVE_YES)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitForTag(AdminTags.CAKES_ADD)
        rule.waitUntilGone(AdminTags.cakeRow(HIDDEN_CAKE))
    }

    @Test
    fun removingTheOnlyActiveCakeNeverOpensTheDialog() = withStub {
        openCakes()
        rule.tap(AdminTags.cakeRow(FIXTURE_CAKE))
        rule.tap(AdminTags.CAKE_FORM_REMOVE, scroll = true)
        rule.waitForTag(AdminTags.TOAST)
        assertFalse(rule.has(AdminTags.CAKE_FORM_REMOVE_YES))
    }

    @Test
    fun changingThePriceSavesAndReturnsToTheList() = withStub {
        openCakes()
        rule.tap(AdminTags.cakeRow(FIXTURE_CAKE))
        rule.typeInto(AdminTags.CAKE_FORM_PRICE, "160000")
        rule.tap(AdminTags.CAKE_FORM_SAVE)
        rule.waitForTag(AdminTags.TOAST)
        rule.waitForTag(AdminTags.CAKES_ADD)
    }

    @Test
    fun leavingADirtyFormAsksBeforeDiscarding() = withStub {
        openCakes()
        rule.tap(AdminTags.CAKES_ADD)
        rule.typeInto(AdminTags.CAKE_FORM_NAME, "Abc")
        rule.tap(AdminTags.NAV_BACK)
        rule.tap(AdminTags.DISCARD_KEEP)
        assertTrue(rule.has(AdminTags.CAKE_FORM_NAME))
        rule.tap(AdminTags.NAV_BACK)
        rule.tap(AdminTags.DISCARD_CONFIRM)
        rule.waitForTag(AdminTags.CAKES_ADD)
    }
}
