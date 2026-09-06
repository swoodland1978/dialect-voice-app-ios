package com.dialect.voice.shared

import com.dialect.voice.shared.prompt.PromptBuilder
import kotlin.test.Test
import kotlin.test.assertTrue

class PromptBuilderTest {

    @Test
    fun fullPromptIncludesDialectPromptAndAllThreeHints() {
        val full = PromptBuilder.buildFullSystemPrompt(
            dialectSystemPrompt = "PERSONA_MARKER",
            todayFormatted = "2 September 2026"
        )
        assertTrue(full.contains("PERSONA_MARKER"), "dropped the dialect's own prompt")
        assertTrue(full.contains("Match your reply's length"), "dropped the length hint")
        assertTrue(full.contains("writing a book about different farts"), "dropped the sparetime hint")
        assertTrue(full.contains("2 September 2026"), "didn't thread the date through")
        assertTrue(full.contains("training data has a cutoff"), "dropped the staleness hedge")
    }

    @Test
    fun neverHardCodesASpecificOfficeHolder() {
        // Regression guard for the exact mistake made (and reverted) on the Android side:
        // this must stay a general hedge, never a specific "X is currently president" fact.
        val full = PromptBuilder.buildFullSystemPrompt("persona", "1 January 2030")
        assertTrue(!full.contains("Trump", ignoreCase = true))
        assertTrue(!full.contains("Biden", ignoreCase = true))
    }
}
