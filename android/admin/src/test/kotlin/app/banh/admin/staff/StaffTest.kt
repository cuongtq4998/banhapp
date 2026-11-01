package app.banh.admin.staff

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.Problem
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.testing.FakeOwnerApi
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
class StaffTest {
    private val api = FakeOwnerApi()
    private val store by lazy { SettingsViewModel(api) }

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    private fun model() = StaffViewModel(api, store)

    @Test
    fun theStoreCountsActiveStaffAndNotTheOwner() {
        assertEquals(1, store.state.value.activeStaff)
        assertEquals(2, store.state.value.staff?.size)
    }

    @Test
    fun addNeedsBothFieldsAndAValidAddress() {
        val m = model()
        m.dispatch(StaffIntent.OpenAdd)
        assertFalse(m.state.value.add!!.canSave)
        m.dispatch(StaffIntent.Name("Nhan Vien B"))
        m.dispatch(StaffIntent.Email("nope"))
        m.dispatch(StaffIntent.SaveAdd)
        assertEquals(Problem.EmailInvalid, m.state.value.add!!.problems[StaffField.EMAIL])
        m.dispatch(StaffIntent.Email("b@example.com"))
        m.dispatch(StaffIntent.SaveAdd)
        assertTrue(api.calls.contains("addStaff Nhan Vien B b@example.com"))
        assertNull(m.state.value.add)
        assertEquals(OwnerToast.STAFF_ADDED, store.state.value.toast)
    }

    @Test
    fun takenAddressAndTheLimitHaveTheirOwnMessages() {
        val sheet = AddStaffSheet("A", "a@b.vn", saving = true)
        val taken = reduceStaff(StaffState(add = sheet), StaffIntent.AddFailed(OwnerFailure.Code("EMAIL_TAKEN")))
        assertEquals(Problem.Taken, taken.add!!.problems[StaffField.EMAIL])
        assertEquals(StaffBanner.FULL, reduceStaff(StaffState(add = sheet), StaffIntent.AddFailed(OwnerFailure.Code("STAFF_LIMIT_REACHED"))).add!!.banner)
        assertEquals(StaffBanner.OFFLINE, reduceStaff(StaffState(add = sheet), StaffIntent.AddFailed(OwnerFailure.Offline)).add!!.banner)
        assertFalse(taken.add!!.saving)
    }

    @Test
    fun deactivatingAsksFirstReactivatingDoesNot() {
        val m = model()
        m.dispatch(StaffIntent.OpenDetail("a2"))
        m.dispatch(StaffIntent.AskDeactivate)
        assertTrue(m.state.value.confirmDeactivate)
        assertTrue(api.calls.none { it.startsWith("setStaffActive") })
        m.dispatch(StaffIntent.SetActive(false))
        assertTrue(api.calls.contains("setStaffActive a2 false"))
        assertNull(m.state.value.detailId)
        m.dispatch(StaffIntent.OpenDetail("a2"))
        m.dispatch(StaffIntent.SetActive(true))
        assertTrue(api.calls.contains("setStaffActive a2 true"))
    }

    @Test
    fun reactivatingAtTheLimitAndAProtectedOwnerShowTheirMessages() {
        val limit = reduceStaff(StaffState(detailId = "a2", busy = true), StaffIntent.SetFailed(OwnerFailure.Code("STAFF_LIMIT_REACHED")))
        assertEquals(StaffToast.FULL, limit.toast)
        assertFalse(limit.busy)
        assertEquals(StaffToast.ERROR, reduceStaff(StaffState(busy = true), StaffIntent.SetFailed(OwnerFailure.Code("OWNER_PROTECTED"))).toast)
    }
}
