package app.banh.admin.shop

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.Problem
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.testing.FakeOwnerApi
import app.banh.admin.testing.ownerSettingsFixture
import app.banh.core.network.FieldIssue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ShopTest {
    private val api = FakeOwnerApi()
    private val store by lazy { SettingsViewModel(api) }
    private val stored = ownerSettingsFixture.shop

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    @Test
    fun saveIsOffUntilAValueDiffers() {
        assertFalse(ShopState(stored).canSave)
        assertTrue(reduceShop(ShopState(stored), ShopIntent.Name("x")).canSave)
    }

    @Test
    fun everyBadFieldIsListedAtOnce() {
        val problems = validateShop(ShopState(stored, name = "", greeting = "", phone = "abc", zalo = "ab"))
        assertEquals(setOf(ShopField.NAME, ShopField.GREETING, ShopField.PHONE, ShopField.ZALO), problems.keys)
        assertEquals(Problem.Phone, problems[ShopField.PHONE])
    }

    @Test
    fun theGreetingStopsAt300CharactersAndThePhoneIsSentInE164() {
        assertEquals(GREETING_MAX, reduceShop(ShopState(stored), ShopIntent.Greeting("a".repeat(400))).greeting.length)
        val model = ShopViewModel(ShopState(stored, phone = "0912 345 678"), api, store)
        model.dispatch(ShopIntent.Name("Tiem Moi"))
        model.dispatch(ShopIntent.Save)
        assertTrue(api.calls.contains("saveShop +84912345678"))
        assertTrue(model.state.value.done)
        assertEquals(OwnerToast.SAVED, store.state.value.toast)
    }

    @Test
    fun serverFieldProblemsLandOnTheirFields() {
        val issues = listOf(FieldIssue("name", "NAME_REQUIRED"), FieldIssue("greeting", "GREETING_TOO_LONG"), FieldIssue("phone_contact", "PHONE_CONTACT_INVALID"))
        val state = reduceShop(ShopState(stored, saving = true), ShopIntent.Failed(OwnerFailure.Fields(issues)))
        assertEquals(Problem.Required, state.problems[ShopField.NAME])
        assertEquals(Problem.TooLong(GREETING_MAX), state.problems[ShopField.GREETING])
        assertEquals(Problem.Phone, state.problems[ShopField.PHONE])
        assertFalse(state.saving)
    }

    @Test
    fun offlineKeepsTheFormWithItsOwnMessage() {
        val model = ShopViewModel(ShopState(stored, name = "New"), api, store)
        api.failure = app.banh.admin.testing.offline()
        model.dispatch(ShopIntent.Save)
        assertEquals(ShopBanner.OFFLINE, model.state.value.banner)
        assertEquals("New", model.state.value.name)
    }
}
