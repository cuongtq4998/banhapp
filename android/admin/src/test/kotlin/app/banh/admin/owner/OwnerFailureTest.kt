package app.banh.admin.owner

import app.banh.admin.testing.Fixtures
import app.banh.admin.testing.httpError
import app.banh.admin.testing.offline
import app.banh.core.model.OwnerSettings
import app.banh.core.model.StaffList
import app.banh.core.network.ApiException
import app.banh.core.network.ErrorCodes
import app.banh.core.network.FieldIssue
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OwnerFailureTest {
    private fun http(status: Int, code: String, fields: List<FieldIssue> = emptyList()) = ApiException.Http(status, code, "ERR", null, null, fields, null)

    @Test
    fun namedRefusalsKeepTheirCode() {
        assertEquals(OwnerFailure.Code("LAST_ACTIVE_CAKE"), httpError(409, "LAST_ACTIVE_CAKE").toFailure())
        assertEquals(OwnerFailure.Code("CAKE_LIMIT_REACHED"), httpError(409, "CAKE_LIMIT_REACHED").toFailure())
        assertEquals(OwnerFailure.Code("SLOT_DUPLICATE"), httpError(422, "SLOT_DUPLICATE").toFailure())
        assertEquals(OwnerFailure.Code("EMAIL_TAKEN"), httpError(409, "EMAIL_TAKEN").toFailure())
        assertEquals(OwnerFailure.Code("STAFF_LIMIT_REACHED"), httpError(409, "STAFF_LIMIT_REACHED").toFailure())
        assertEquals(OwnerFailure.Code("OWNER_PROTECTED"), httpError(409, "OWNER_PROTECTED").toFailure())
        assertEquals(OwnerFailure.Code("IMAGE_TOO_LARGE"), httpError(413, "IMAGE_TOO_LARGE").toFailure())
    }

    @Test
    fun otherStatusesMapToTheirKind() {
        assertEquals(OwnerFailure.Offline, offline().toFailure())
        assertEquals(OwnerFailure.Gone, httpError(404, "NOT_FOUND").toFailure())
        assertEquals(OwnerFailure.Forbidden, httpError(403, ErrorCodes.FORBIDDEN).toFailure())
        assertEquals(OwnerFailure.Generic, httpError(500, "INTERNAL_ERROR").toFailure())
        assertEquals(OwnerFailure.Generic, ApiException.InvalidResponse().toFailure())
    }

    @Test
    fun aValidationFailureCarriesEveryFieldProblem() {
        val issues = listOf(FieldIssue("name", "NAME_REQUIRED"), FieldIssue("price_vnd", "PRICE_VND_OUT_OF_RANGE"), FieldIssue("image", "IMAGE_TYPE_UNSUPPORTED"))
        val failure = http(422, ErrorCodes.VALIDATION_FAILED, issues).toFailure() as OwnerFailure.Fields
        val problems = failure.problems(mapOf("price_vnd" to Limits(1, 100)))
        assertEquals(Problem.Required, problems["name"])
        assertEquals(Problem.Range(1, 100), problems["price_vnd"])
        assertEquals(Problem.ImageType, problems["image"])
    }

    @Test
    fun serverCodesMapToTheSameProblemsAsThePhoneChecks() {
        val limits = Limits(1, 300)
        assertEquals(Problem.TooLong(300), FieldIssue("greeting", "GREETING_TOO_LONG").toProblem(limits))
        assertEquals(Problem.Phone, FieldIssue("phone_contact", "PHONE_CONTACT_INVALID").toProblem(limits))
        assertEquals(Problem.Taken, FieldIssue("name", "NAME_TAKEN").toProblem(limits))
        assertEquals(Problem.MinAboveLimit, FieldIssue("min_qty", "MIN_QTY_OUT_OF_RANGE").toProblem(limits))
        assertEquals(Problem.ImageRead, FieldIssue("image", "IMAGE_DIMENSIONS_INVALID").toProblem(limits))
    }

    @Test
    fun attemptTurnsExceptionsIntoOutcomes() = runTest {
        assertEquals(Outcome.Ok(1), attempt { 1 })
        assertEquals(Outcome.Failed(OwnerFailure.Offline), attempt { throw offline() })
        assertEquals(Outcome.Ended, attempt { throw app.banh.admin.auth.SessionEndedException() })
    }

    @Test
    fun theOwnerFixturesDecodeIntoTheModels() {
        val json = Json { ignoreUnknownKeys = true }
        val settings = json.decodeFromString<OwnerSettings>(Fixtures.body("owner-settings"))
        assertEquals(60, settings.ordering.dailyLimit)
        assertEquals("08:00", settings.slots.single().start)
        assertEquals(2, json.decodeFromString<StaffList>(Fixtures.body("owner-staff-list")).accounts.size)
        val saved = json.decodeFromString<app.banh.core.model.OrderingSaved>(Fixtures.body("owner-ordering-saved"))
        assertEquals("2026-11-05", saved.overLimit.single().date)
        assertTrue(json.decodeFromString<app.banh.core.model.Cake>(Fixtures.body("owner-cake-created")).isActive)
    }
}
