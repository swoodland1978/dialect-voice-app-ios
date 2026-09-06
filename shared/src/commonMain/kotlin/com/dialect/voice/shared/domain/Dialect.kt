package com.dialect.voice.shared.domain

// Dialect definition with system prompt and ElevenLabs voice ID. Deliberately not
// @Serializable / sent over the wire anywhere - system prompts are only ever consumed
// locally to build the request the shared network client sends.
data class Dialect(
    val id: String,
    val label: String,
    val description: String,
    val systemPrompt: String,
    val elevenLabsVoiceId: String
)
