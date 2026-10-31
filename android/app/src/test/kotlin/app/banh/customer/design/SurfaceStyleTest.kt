package app.banh.customer.design

import org.junit.Assert.assertEquals
import org.junit.Test

class SurfaceStyleTest {
    @Test
    fun blurNeedsAndroid12AndNoHighContrast() {
        assertEquals(SurfaceStyle.OPAQUE, surfaceStyleFor(sdkInt = 30, highContrast = false))
        assertEquals(SurfaceStyle.GLASS, surfaceStyleFor(sdkInt = 31, highContrast = false))
        assertEquals(SurfaceStyle.GLASS, surfaceStyleFor(sdkInt = 36, highContrast = false))
        assertEquals(SurfaceStyle.OPAQUE, surfaceStyleFor(sdkInt = 36, highContrast = true))
    }
}
