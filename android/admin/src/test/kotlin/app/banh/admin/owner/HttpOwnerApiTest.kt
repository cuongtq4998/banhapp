package app.banh.admin.owner

import app.banh.admin.auth.StoredSession
import app.banh.admin.push.HttpPushApi
import app.banh.admin.testing.FakeAuthApi
import app.banh.admin.testing.Fixtures
import app.banh.admin.testing.MemoryVault
import app.banh.admin.testing.newSession
import app.banh.core.network.ApiClient
import kotlinx.coroutines.test.runTest
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HttpOwnerApiTest {
    private val requests = mutableListOf<Request>()
    private val bodies = mutableListOf<String>()
    private var answer = 200 to Fixtures.body("owner-cake-created")

    private val http = OkHttpClient.Builder().addInterceptor(
        Interceptor { chain ->
            requests += chain.request()
            bodies += chain.request().body?.let { Buffer().also { b -> it.writeTo(b) }.readUtf8() }.orEmpty()
            Response.Builder().request(chain.request()).protocol(Protocol.HTTP_1_1).code(answer.first).message("x")
                .body(answer.second.toResponseBody("application/json".toMediaType())).build()
        },
    ).build()
    private val session = newSession(FakeAuthApi(), MemoryVault(StoredSession("rt")))
    private val client = ApiClient(http, "http://x.invalid/".toHttpUrl())
    private val api = HttpOwnerApi(client, session)

    @Test
    fun aPatchSendsOnlyTheFieldsThatChanged() = runTest {
        session.restore()
        api.changeCake("c1", CakeChanges(priceVnd = 160000, isActive = false))
        assertEquals("PATCH", requests.last().method)
        assertEquals("/v1/owner/cakes/c1", requests.last().url.encodedPath)
        assertEquals("""{"price_vnd":160000,"is_active":false}""", bodies.last())
        assertEquals("Bearer at_1", requests.last().header("Authorization"))
    }

    @Test
    fun addCakeSendsAMultipartWithTheThreeTextFieldsAndOneJpegFile() = runTest {
        session.restore()
        val progress = mutableListOf<Int>()
        val cake = api.addCake(CakeUpload("Banh Mau", "Banh mau", 150000, byteArrayOf(1, 2, 3))) { progress += it }
        val request = requests.last()
        assertTrue(request.body!!.contentType().toString().startsWith("multipart/form-data"))
        val text = bodies.last()
        assertTrue(text.contains("name=\"name\"") && text.contains("Banh Mau"))
        assertTrue(text.contains("name=\"price_vnd\"") && text.contains("150000"))
        assertEquals(1, Regex("name=\"image\"").findAll(text).count())
        assertTrue(text.contains("Content-Type: image/jpeg"))
        assertEquals(100, progress.last())
        assertEquals("Banh Mau", cake.name)
    }

    @Test
    fun theImpactPreviewIsAGetWithTheLimit() = runTest {
        session.restore()
        answer = 200 to Fixtures.body("owner-ordering-impact")
        val impact = api.impact(60)
        assertEquals("GET", requests.last().method)
        assertEquals("60", requests.last().url.queryParameter("daily_limit"))
        assertEquals("2026-11-05", impact.overLimit.single().date)
    }

    @Test
    fun orderingSaveReturnsTheDatesFoundAtSaveTime() = runTest {
        session.restore()
        answer = 200 to Fixtures.body("owner-ordering-saved")
        val saved = api.saveOrdering(60, 2, 2)
        assertEquals("PUT", requests.last().method)
        assertEquals("""{"daily_limit":60,"lead_days":2,"min_qty":2}""", bodies.last())
        assertEquals(1, saved.count)
    }

    @Test
    fun removeAnswers204WithoutABody() = runTest {
        session.restore()
        answer = 204 to ""
        api.removeCake("c1")
        assertEquals("DELETE", requests.last().method)
    }

    @Test
    fun theSlotAndDistrictBodiesUseTheApiNames() = runTest {
        session.restore()
        answer = 201 to Fixtures.body("owner-slot-created")
        api.addSlot("08:00", "10:00")
        assertEquals("""{"start":"08:00","end":"10:00"}""", bodies.last())
        answer = 201 to Fixtures.body("owner-district-created")
        api.addDistrict("Quan An Phu", 20000)
        assertEquals("""{"name":"Quan An Phu","delivery_fee_vnd":20000}""", bodies.last())
    }

    @Test
    fun theStaffListAndAddUseTheFixtures() = runTest {
        session.restore()
        answer = 200 to Fixtures.body("owner-staff-list")
        assertEquals(2, api.staff().size)
        answer = 201 to Fixtures.body("owner-staff-created")
        assertEquals("nhanvien.a@example.com", api.addStaff("Nhan Vien A", "nhanvien.a@example.com").email)
    }

    @Test
    fun theTokenIsRegisteredWithPutAndTheAndroidPlatform() = runTest {
        session.restore()
        answer = 204 to ""
        HttpPushApi(client, session).register("tok")
        assertEquals("PUT", requests.last().method)
        assertEquals("/v1/admin/push-token", requests.last().url.encodedPath)
        assertEquals("""{"platform":"android","token":"tok"}""", bodies.last())
    }
}
