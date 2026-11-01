package app.banh.admin.rules

import app.banh.admin.owner.OwnerFailure
import app.banh.admin.owner.OwnerToast
import app.banh.admin.owner.Problem
import app.banh.admin.owner.SettingsViewModel
import app.banh.admin.testing.FakeOwnerApi
import app.banh.admin.testing.ownerSettingsFixture
import app.banh.core.model.OverLimitDay
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
class RulesTest {
    private val api = FakeOwnerApi()
    private val store by lazy { SettingsViewModel(api) }
    private val stored = ownerSettingsFixture.ordering
    private val day = OverLimitDay("2026-11-05", 98)

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After fun tearDown() = Dispatchers.resetMain()

    private fun model() = RulesViewModel(RulesState(stored), api, store)

    @Test
    fun saveIsOffUntilAValueDiffers() {
        assertFalse(RulesState(stored).canSave)
        assertTrue(reduceRules(RulesState(stored), RulesIntent.Lead("3")).canSave)
    }

    @Test
    fun everyBadFieldIsListedAndTheMinimumMayNotExceedTheLimit() {
        val bad = RulesState(stored, limit = "0", lead = "15", min = "21")
        val problems = validateRules(bad)
        assertEquals(Problem.Range(1, LIMIT_MAX), problems[RulesField.LIMIT])
        assertEquals(Problem.Range(0, LEAD_MAX), problems[RulesField.LEAD])
        assertEquals(Problem.Range(1, MIN_MAX), problems[RulesField.MIN])
        assertEquals(Problem.MinAboveLimit, validateRules(RulesState(stored, limit = "10", min = "15"))[RulesField.MIN])
        assertTrue(validateRules(RulesState(stored, limit = "10", min = "10")).isEmpty())
    }

    @Test
    fun aLowerLimitAsksTheServerWhichDatesAreAffectedAndWaitsForTheOwner() {
        api.impactDays = listOf(day)
        val m = model()
        m.dispatch(RulesIntent.Limit("40"))
        m.dispatch(RulesIntent.Save)
        assertEquals(listOf("impact 40"), api.calls.filter { it.startsWith("impact") || it.startsWith("save") })
        assertEquals(listOf(day), m.state.value.warning?.days)
        assertFalse(m.state.value.done)
    }

    @Test
    fun confirmingTheWarningSavesAndDoesNotShowTheSameListAgain() {
        api.impactDays = listOf(day)
        api.savedDays = listOf(day)
        val m = model()
        m.dispatch(RulesIntent.Limit("40"))
        m.dispatch(RulesIntent.Save)
        m.dispatch(RulesIntent.SaveAnyway)
        assertTrue(api.calls.contains("saveOrdering 40 ${stored.leadDays} ${stored.minQty}"))
        assertTrue(m.state.value.done)
        assertNull(m.state.value.warning)
        assertEquals(OwnerToast.SAVED, store.state.value.toast)
    }

    @Test
    fun aListThatDiffersFromThePreviewIsShownAfterTheSave() {
        api.impactDays = emptyList()
        api.savedDays = listOf(day)
        val m = model()
        m.dispatch(RulesIntent.Limit("40"))
        m.dispatch(RulesIntent.Save)
        assertEquals(listOf(day), m.state.value.warning?.days)
        assertTrue(m.state.value.warning!!.afterSave)
        assertFalse(m.state.value.done)
        m.dispatch(RulesIntent.Dismiss)
        assertTrue(m.state.value.done)
    }

    @Test
    fun aRaisedLimitSavesAtOnceWithoutAPreview() {
        val m = model()
        m.dispatch(RulesIntent.Limit("80"))
        m.dispatch(RulesIntent.Save)
        assertTrue(api.calls.none { it.startsWith("impact") })
        assertTrue(m.state.value.done)
    }

    @Test
    fun aServerRefusalAndAnOfflineSaveKeepTheForm() {
        val refused = reduceRules(RulesState(stored, min = "70"), RulesIntent.Failed(OwnerFailure.Fields(listOf(app.banh.core.network.FieldIssue("min_qty", "MIN_QTY_OUT_OF_RANGE")))))
        assertEquals(Problem.MinAboveLimit, refused.problems[RulesField.MIN])
        assertEquals("70", refused.min)
        assertEquals(RulesBanner.OFFLINE, reduceRules(RulesState(stored), RulesIntent.Failed(OwnerFailure.Offline)).banner)
        assertEquals(RulesBanner.ERROR, reduceRules(RulesState(stored), RulesIntent.Failed(OwnerFailure.Generic)).banner)
    }

    @Test
    fun leavingADirtyFormAsksFirst() {
        assertFalse(reduceRules(RulesState(stored), RulesIntent.Back).discard)
        assertTrue(reduceRules(RulesState(stored, lead = "5"), RulesIntent.Back).discard)
    }
}
