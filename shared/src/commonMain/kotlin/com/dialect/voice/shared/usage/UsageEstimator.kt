package com.dialect.voice.shared.usage

// Same rule of thumb as the backend (functions/src/lib/usage.ts): ElevenLabs' own guidance
// is ~1000 characters ~= 1 minute of audio, reused for text too so both meters use one
// consistent length proxy. Kept identical to the server's formula so a client-side estimate
// (e.g. "this reply will cost about..." before it's sent) never drifts from what actually
// gets charged - the server is still the source of truth for the real charge.
private const val CHARS_PER_MINUTE = 1000

fun estimateSeconds(text: String): Int {
    val chars = text.length
    return kotlin.math.ceil((chars.toDouble() / CHARS_PER_MINUTE) * 60).toInt()
}
