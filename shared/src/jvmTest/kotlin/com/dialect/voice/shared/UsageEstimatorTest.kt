package com.dialect.voice.shared

import com.dialect.voice.shared.usage.estimateSeconds
import kotlin.test.Test
import kotlin.test.assertEquals

class UsageEstimatorTest {

    @Test
    fun matchesTheServersCharsPerMinuteFormula() {
        // functions/src/lib/usage.ts: Math.ceil((text.length / 1000) * 60)
        assertEquals(0, estimateSeconds(""))
        assertEquals(6, estimateSeconds("a".repeat(100)))
        assertEquals(60, estimateSeconds("a".repeat(1000)))
        assertEquals(61, estimateSeconds("a".repeat(1001))) // ceil, not floor/round
    }
}
