package app.banh.customer.data

import org.junit.Assert.assertEquals
import org.junit.Test

class LoadTest {
    @Test
    fun mapTransformsOnlyReadyValues() {
        assertEquals(Load.Ready(4), Load.Ready(2).map { it * 2 })
        val loading: Load<Int> = Load.Loading
        val failed: Load<Int> = Load.Failed(LoadFailure.NETWORK)
        assertEquals(Load.Loading, loading.map { it * 2 })
        assertEquals(Load.Failed(LoadFailure.NETWORK), failed.map { it * 2 })
    }

    @Test
    fun flatMapCanTurnAReadyValueIntoAFailure() {
        val result = Load.Ready(1).flatMap { Load.Failed(LoadFailure.OTHER) }

        assertEquals(Load.Failed(LoadFailure.OTHER), result)
    }
}
