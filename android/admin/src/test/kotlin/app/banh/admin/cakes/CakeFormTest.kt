package app.banh.admin.cakes

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.Problem
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.photo.PhotoEncoder
import app.banh.admin.photo.PhotoResult
import app.banh.admin.photo.PixelSize
import app.banh.admin.testing.FakeOwnerApi
import app.banh.admin.testing.cakeFixture
import app.banh.admin.testing.httpError
import app.banh.admin.testing.offline
import kotlinx.coroutines.CompletableDeferred
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
class CakeFormTest {
    private val api = FakeOwnerApi()
    private val store by lazy { SettingsViewModel(api) }
    private var encoded: PhotoResult = PhotoResult.Ready(byteArrayOf(1, 2, 3), PixelSize(600, 400))
    private val encoder = PhotoEncoder { encoded }

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    private fun add() = CakeFormViewModel(CakeFormState(), api, encoder, store)

    private fun edit(onlyActive: Boolean = false) = CakeFormViewModel(CakeFormState(original = cakeFixture, onlyActive = onlyActive), api, encoder, store)

    private fun CakeFormViewModel.fill(name: String = "Banh Moi", picture: Boolean = true) {
        dispatch(CakeIntent.Name(name))
        dispatch(CakeIntent.Description("Banh ngon"))
        dispatch(CakeIntent.Price("150.000"))
        if (picture) dispatch(CakeIntent.Pick("content://photo/1"))
    }

    @Test
    fun saveIsOffOnAnEmptyAddFormAndOnceSomethingIsTyped() {
        assertFalse(CakeFormState().canSave)
        assertTrue(reduceCake(CakeFormState(), CakeIntent.Name("a")).canSave)
    }

    @Test
    fun savingListsEveryMissingFieldAtOnce() {
        val state = reduceCake(reduceCake(CakeFormState(), CakeIntent.Price("0")), CakeIntent.Save)
        assertEquals(setOf(CakeField.NAME, CakeField.DESC, CakeField.PRICE, CakeField.IMAGE), state.problems.keys)
        assertEquals(Problem.ImageRequired, state.problems[CakeField.IMAGE])
        assertEquals(CakeBusy.NONE, state.busy)
    }

    @Test
    fun addUploadsTheEncodedPictureAndTheValuesThenFinishesAndReloads() {
        val model = add()
        model.fill()
        model.dispatch(CakeIntent.Save)
        assertEquals(listOf(1, 2, 3), api.lastUpload!!.jpeg.map { it.toInt() })
        assertEquals(150000L, api.lastUpload!!.priceVnd)
        assertEquals(CakeDone.ADDED, model.state.value.done)
        assertEquals(OwnerToast.CAKE_ADDED, store.state.value.toast)
        assertTrue(api.calls.count { it == "settings" } >= 2)
    }

    @Test
    fun aRejectedPictureIsNotKeptAndNamesTheReason() {
        encoded = PhotoResult.Rejected(Problem.ImageType)
        val model = add()
        model.dispatch(CakeIntent.Pick("content://x"))
        assertNull(model.state.value.photo)
        assertEquals(Problem.ImageType, model.state.value.photoProblem)
    }

    @Test
    fun theUploadCanBeStoppedAndNothingIsCreated() {
        val model = add()
        model.fill()
        api.gate = CompletableDeferred()
        model.dispatch(CakeIntent.Save)
        assertEquals(CakeBusy.SAVING, model.state.value.busy)
        model.dispatch(CakeIntent.CancelUpload)
        assertEquals(CakeBusy.NONE, model.state.value.busy)
        assertEquals(CakeDone.NONE, model.state.value.done)
        assertNull(api.lastUpload)
        assertEquals("Banh Moi", model.state.value.name)
    }

    @Test
    fun errorsKeepTheValuesAndTheirOwnMessages() {
        val base = CakeFormState(name = "A", description = "B", price = "5", photo = null)
        assertEquals(CakeBanner.CAKES_FULL, base.failed(OwnerFailure.Code("CAKE_LIMIT_REACHED")).banner)
        assertEquals(CakeBanner.OFFLINE, base.failed(OwnerFailure.Offline).banner)
        assertEquals(CakeBanner.UPLOAD_FAILED, base.failed(OwnerFailure.Generic).banner)
        assertEquals(Problem.ImageSize, base.failed(OwnerFailure.Code("IMAGE_TOO_LARGE")).photoProblem)
        assertEquals("A", base.failed(OwnerFailure.Generic).name)
        val taken = base.failed(OwnerFailure.Fields(listOf(app.banh.core.network.FieldIssue("name", "NAME_TAKEN"))))
        assertEquals(Problem.Taken, taken.problems[CakeField.NAME])
    }

    @Test
    fun theLastActiveCakeCannotBeHiddenOrRemoved() {
        val only = edit(onlyActive = true)
        only.dispatch(CakeIntent.Active(false))
        assertTrue(only.state.value.active)
        assertEquals(CakeToast.LAST_CAKE, only.state.value.toast)
        only.dispatch(CakeIntent.ToastShown)
        only.dispatch(CakeIntent.AskRemove)
        assertEquals(CakeDialog.NONE, only.state.value.dialog)
        assertEquals(CakeToast.LAST_CAKE, only.state.value.toast)
    }

    @Test
    fun aServerRefusalToHideSwitchesTheCakeBackOn() {
        val state = CakeFormState(original = cakeFixture, active = false).failed(OwnerFailure.Code("LAST_ACTIVE_CAKE"))
        assertTrue(state.active)
        assertEquals(CakeToast.LAST_CAKE, state.toast)
    }

    @Test
    fun editSendsOnlyWhatChanged() {
        val model = edit()
        model.dispatch(CakeIntent.Price("160000"))
        model.dispatch(CakeIntent.Active(false))
        model.dispatch(CakeIntent.Save)
        assertTrue(api.calls.any { it.contains("priceVnd=160000") && it.contains("isActive=false") && it.contains("name=null") })
        assertEquals(CakeDone.SAVED, model.state.value.done)
    }

    @Test
    fun removeAsksThenDeletesAndLeaves() {
        val model = edit()
        model.dispatch(CakeIntent.AskRemove)
        assertEquals(CakeDialog.REMOVE, model.state.value.dialog)
        model.dispatch(CakeIntent.RemoveYes)
        assertTrue(api.calls.contains("removeCake ${cakeFixture.cakeId}"))
        assertEquals(CakeDone.REMOVED, model.state.value.done)
        assertEquals(OwnerToast.CAKE_REMOVED, store.state.value.toast)
    }

    @Test
    fun aCakeRemovedElsewhereShowsTheGoneState() {
        api.failure = httpError(404, "NOT_FOUND")
        val model = edit()
        model.dispatch(CakeIntent.Price("1"))
        model.dispatch(CakeIntent.Save)
        assertTrue(model.state.value.gone)
    }

    @Test
    fun leavingADirtyFormAsksFirst() {
        assertEquals(CakeDialog.NONE, reduceCake(CakeFormState(), CakeIntent.Back).dialog)
        assertEquals(CakeDialog.DISCARD, reduceCake(CakeFormState(name = "x"), CakeIntent.Back).dialog)
    }

    @Test
    fun cakesAreSortedActiveFirstThenByName() {
        val cakes = listOf(cakeFixture.copy(name = "b", isActive = false), cakeFixture.copy(name = "z"), cakeFixture.copy(name = "A", isActive = false), cakeFixture.copy(name = "c"))
        assertEquals(listOf("c", "z", "A", "b"), sortedCakes(cakes).map { it.name })
    }

    @Test
    fun noticeOfOfflineIsReportedAsOffline() {
        api.failure = offline()
        val model = add()
        model.fill()
        model.dispatch(CakeIntent.Save)
        assertEquals(CakeBanner.OFFLINE, model.state.value.banner)
    }
}
