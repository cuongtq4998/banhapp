package app.banh.customer.lookup

import app.banh.customer.data.lookup.OrderLookupApi
import app.banh.customer.data.network.ApiErrorCode
import app.banh.customer.data.network.ApiException
import app.banh.customer.data.network.FieldIssue
import app.banh.customer.testing.MainDispatcherRule
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class LookupViewModelTest {
    @get:Rule
    val mainDispatcher = MainDispatcherRule()

    private val phone = "0900000001"
    private fun page(name: String) = Result.success(lookupFixture(name))

    @Test
    fun invalidHintIsNeverSent() = runTest {
        val api = FakeLookupApi()
        val vm = LookupViewModel(api)
        vm.onPhoneChanged("12345")
        vm.submit()
        assertTrue(vm.state.value.phoneError)
        assertTrue(api.calls.isEmpty())
    }

    @Test
    fun submitShowsOrdersAndAsOf() = runTest {
        val api = FakeLookupApi(page("order-lookup-answer-open.json"))
        val vm = LookupViewModel(api)
        vm.onPhoneChanged(phone)
        vm.submit()
        runCurrent()
        assertEquals(4, vm.state.value.orders.size)
        assertEquals("2026-11-02T05:00:00Z", vm.state.value.asOf)
        assertEquals(listOf(phone to null), api.calls)
    }

    @Test
    fun pagingAppendsAndLastPageEndsTheCursor() = runTest {
        val api = FakeLookupApi(page("order-lookup-answer-page-one.json"), page("order-lookup-answer-last-page.json"))
        val vm = LookupViewModel(api)
        vm.startWith(phone)
        runCurrent()
        val cursor = vm.state.value.nextCursor
        vm.loadMore()
        runCurrent()
        assertEquals(12, vm.state.value.orders.size)
        assertNull(vm.state.value.nextCursor)
        assertEquals(phone to cursor, api.calls[1])
        vm.loadMore()
        runCurrent()
        assertEquals(2, api.calls.size)
    }

    @Test
    fun invalidCursorRestartsAtPageOne() = runTest {
        val bad = Result.failure<app.banh.customer.data.lookup.LookupAnswer>(validation("CURSOR_INVALID", "cursor"))
        val api = FakeLookupApi(page("order-lookup-answer-page-one.json"), bad, page("order-lookup-answer-page-one.json"))
        val vm = LookupViewModel(api)
        vm.startWith(phone)
        runCurrent()
        vm.loadMore()
        runCurrent()
        assertEquals(null, api.calls[2].second)
        assertEquals(10, vm.state.value.orders.size)
        assertNull(vm.state.value.problem)
    }

    @Test
    fun refreshRestartsAtPageOne() = runTest {
        val api = FakeLookupApi(page("order-lookup-answer-page-one.json"), page("order-lookup-answer-open.json"))
        val vm = LookupViewModel(api)
        vm.startWith(phone)
        runCurrent()
        vm.refresh()
        runCurrent()
        assertEquals(null, api.calls[1].second)
        assertEquals(4, vm.state.value.orders.size)
    }

    @Test
    fun rateLimitCountsDownAndReenablesSubmit() = runTest {
        val limited = Result.failure<app.banh.customer.data.lookup.LookupAnswer>(ApiException.RateLimited(3, null))
        val vm = LookupViewModel(FakeLookupApi(limited))
        vm.startWith(phone)
        runCurrent()
        assertEquals(LookupProblem.RateLimited(3), vm.state.value.problem)
        assertFalse(vm.state.value.canSubmit)
        advanceTimeBy(1_100)
        assertEquals(LookupProblem.RateLimited(2), vm.state.value.problem)
        advanceTimeBy(2_000)
        assertNull(vm.state.value.problem)
        assertTrue(vm.state.value.canSubmit)
    }

    @Test
    fun offlineKeepsLoadedResultAndAsOf() = runTest {
        val off = Result.failure<app.banh.customer.data.lookup.LookupAnswer>(ApiException.NetworkUnavailable(java.io.IOException()))
        val vm = LookupViewModel(FakeLookupApi(page("order-lookup-answer-open.json"), off))
        vm.startWith(phone)
        runCurrent()
        vm.refresh()
        runCurrent()
        assertEquals(LookupProblem.Offline, vm.state.value.problem)
        assertEquals(4, vm.state.value.orders.size)
        assertEquals("2026-11-02T05:00:00Z", vm.state.value.asOf)
    }

    @Test
    fun serverPhoneRejectionShowsTheFieldError() = runTest {
        val rejected = Result.failure<app.banh.customer.data.lookup.LookupAnswer>(validation("PHONE_INVALID", "phone"))
        val vm = LookupViewModel(FakeLookupApi(rejected))
        vm.startWith(phone)
        runCurrent()
        assertTrue(vm.state.value.phoneError)
    }

    @Test
    fun emptyAnswerIsTheSameForAnyNumber() = runTest {
        val vm = LookupViewModel(FakeLookupApi(page("order-lookup-answer-empty.json")))
        vm.startWith(phone)
        runCurrent()
        assertTrue(vm.state.value.isEmpty)
        assertNull(vm.state.value.problem)
    }

    @Test
    fun viewModelTakesOnlyTheApiSoNothingIsPersisted() {
        val constructors = LookupViewModel::class.java.declaredConstructors
        assertEquals(listOf(OrderLookupApi::class.java.name), constructors.single().parameterTypes.map { it.name })
        val types = LookupViewModel::class.java.declaredFields.map { it.type.name }
        assertTrue(types.none { "SharedPreferences" in it || "DataStore" in it || "SavedStateHandle" in it || "DraftStore" in it })
    }

    private fun validation(code: String, field: String) = ApiException.Service(
        code = ApiErrorCode.VALIDATION_FAILED, messageKey = "ERR_SERVER", httpStatus = 422, requestId = null,
        fields = listOf(FieldIssue(field, code, "ERR_FIELD_INVALID")),
    )
}
