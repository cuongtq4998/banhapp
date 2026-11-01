package app.banh.admin.delivery

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.Problem
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.testing.FakeOwnerApi
import app.banh.admin.testing.httpError
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
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DeliveryTest {
    private val api = FakeOwnerApi()
    private val store by lazy { SettingsViewModel(api) }
    private val district = ownerSettingsFixture.districts.first()
    private val slot = ownerSettingsFixture.slots.first()

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    private fun model() = DeliveryViewModel(api, store)

    @Test
    fun addingADistrictNeedsANameAndAFeeAndSendsWholeDong() {
        val m = model()
        m.dispatch(DeliveryIntent.OpenDistrict(null))
        assertFalse(m.state.value.sheet!!.canSave)
        m.dispatch(DeliveryIntent.Name("Quan Moi"))
        m.dispatch(DeliveryIntent.Fee("25.000"))
        m.dispatch(DeliveryIntent.SaveSheet)
        assertTrue(api.calls.contains("addDistrict Quan Moi 25000"))
        assertNull(m.state.value.sheet)
    }

    @Test
    fun aFeeOfZeroIsRefusedAndNothingIsSent() {
        val m = model()
        m.dispatch(DeliveryIntent.OpenDistrict(null))
        m.dispatch(DeliveryIntent.Name("A"))
        m.dispatch(DeliveryIntent.Fee("0"))
        m.dispatch(DeliveryIntent.SaveSheet)
        assertEquals(Problem.Range(1, FEE_MAX), m.state.value.sheet!!.problems[DeliveryField.FEE])
        assertTrue(api.calls.none { it.startsWith("addDistrict") })
    }

    @Test
    fun aSlotMustStartBeforeItEnds() {
        val m = model()
        m.dispatch(DeliveryIntent.OpenSlot(null))
        m.dispatch(DeliveryIntent.Start("15:00"))
        m.dispatch(DeliveryIntent.End("14:00"))
        m.dispatch(DeliveryIntent.SaveSheet)
        assertEquals(Problem.SlotOrder, m.state.value.sheet!!.problems[DeliveryField.TIME])
        m.dispatch(DeliveryIntent.End("16:00"))
        m.dispatch(DeliveryIntent.SaveSheet)
        assertTrue(api.calls.contains("addSlot 15:00 16:00"))
    }

    @Test
    fun aDuplicateSlotAndADuplicateDistrictNameShowTheirOwnMessage() {
        val sheet = DeliverySheet(SheetKind.SLOT, saving = true)
        val dup = reduceDelivery(DeliveryState(sheet), DeliveryIntent.SheetFailed(OwnerFailure.Code("SLOT_DUPLICATE")))
        assertEquals(Problem.SlotDuplicate, dup.sheet!!.problems[DeliveryField.TIME])
        assertFalse(dup.sheet!!.saving)
        val taken = reduceDelivery(DeliveryState(DeliverySheet(SheetKind.DISTRICT, saving = true)), DeliveryIntent.SheetFailed(OwnerFailure.Fields(listOf(FieldIssue("name", "NAME_TAKEN")))))
        assertEquals(Problem.Taken, taken.sheet!!.problems[DeliveryField.NAME])
    }

    @Test
    fun theLastActiveDistrictAndSlotStayOnWithAToast() {
        api.failure = httpError(409, "LAST_ACTIVE_DISTRICT")
        val m = model()
        m.dispatch(DeliveryIntent.Toggle(SheetKind.DISTRICT, district.districtId, false))
        assertEquals(DeliveryToast.LAST_DISTRICT, m.state.value.toast)
        assertTrue(m.state.value.pending.isEmpty())
        api.failure = httpError(409, "LAST_ACTIVE_SLOT")
        m.dispatch(DeliveryIntent.Toggle(SheetKind.SLOT, slot.slotId, false))
        assertEquals(DeliveryToast.LAST_SLOT, m.state.value.toast)
    }

    @Test
    fun aSwitchSavesAtOnceAndReloads() {
        val m = model()
        m.dispatch(DeliveryIntent.Toggle(SheetKind.SLOT, slot.slotId, false))
        assertTrue(api.calls.any { it.startsWith("changeSlot") && it.contains("isActive=false") })
        assertTrue(m.state.value.pending.isEmpty())
        assertNull(m.state.value.toast)
    }

    @Test
    fun aSwitchIsNotTappableWhileItsOwnChangeRuns() {
        val state = reduceDelivery(DeliveryState(), DeliveryIntent.Toggle(SheetKind.SLOT, "s", false))
        assertEquals(setOf("s"), state.pending)
        assertEquals(state, reduceDelivery(state, DeliveryIntent.Toggle(SheetKind.SLOT, "s", true)))
    }
}
