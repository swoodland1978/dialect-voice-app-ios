package com.dialect.voice.shared

import com.dialect.voice.shared.domain.DIALECTS
import com.dialect.voice.shared.domain.ENABLED_DIALECT_IDS
import com.dialect.voice.shared.domain.getDialectById
import kotlin.test.Test
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlin.test.assertEquals

class DialectsTest {

    @Test
    fun everyEnabledIdResolvesToARealDialect() {
        for (id in ENABLED_DIALECT_IDS) {
            val dialect = getDialectById(id)
            assertNotNull(dialect, "ENABLED_DIALECT_IDS contains \"$id\" but no such entry exists in DIALECTS")
            assertEquals(id, dialect.id)
        }
    }

    @Test
    fun everyDialectHasARealPromptAndVoice() {
        for ((id, dialect) in DIALECTS) {
            assertTrue(dialect.systemPrompt.isNotBlank(), "$id has a blank systemPrompt")
            assertTrue(dialect.elevenLabsVoiceId.isNotBlank(), "$id has a blank elevenLabsVoiceId")
            assertTrue(dialect.label.isNotBlank(), "$id has a blank label")
        }
    }

    @Test
    fun eightDialectsExistFiveEnabled() {
        // Pins the known-good shape from the Android app - catches an accidental deletion
        // during a future edit rather than silently shipping fewer dialects than intended.
        assertEquals(8, DIALECTS.size)
        assertEquals(5, ENABLED_DIALECT_IDS.size)
    }
}
