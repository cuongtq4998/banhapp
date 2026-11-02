package app.banh.customer.lookup

import app.banh.customer.data.lookup.LookupAnswer
import app.banh.customer.data.lookup.OrderLookupApi
import app.banh.customer.data.network.ApiJson
import app.banh.customer.testing.ContractFixtures

fun lookupFixture(name: String): LookupAnswer = ApiJson.decodeFromString(LookupAnswer.serializer(), ContractFixtures.read(name))

/** Replays queued results in order and records every call as (phone, cursor). */
class FakeLookupApi(vararg results: Result<LookupAnswer>) : OrderLookupApi {
    private val queue = ArrayDeque(results.toList())
    val calls = mutableListOf<Pair<String, String?>>()

    override suspend fun lookup(phone: String, cursor: String?): LookupAnswer {
        calls += phone to cursor
        return queue.removeFirst().getOrThrow()
    }
}
