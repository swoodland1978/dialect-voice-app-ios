package com.dialect.voice.shared.domain

// Mirrors users/{uid} in Firestore - same shape as the Android app's UserAccountState, since
// both clients read the same backend (regional-dialect-ccd37) and the same Cloud Functions
// own all writes. Two separate running balances in seconds, seeded with a one-time free grant
// on first sign-in and topped up together by a credit purchase, spent independently, never
// resetting or expiring on their own.
data class UserAccountState(
    val creditSecondsRemaining: Int = 0, // voice (ElevenLabs TTS)
    val textSecondsRemaining: Int = 0 // text (OpenAI chat)
) {
    val hasCredit: Boolean
        get() = creditSecondsRemaining > 0

    val hasTextCredit: Boolean
        get() = textSecondsRemaining > 0

    val isLowCredit: Boolean
        get() = hasCredit && creditSecondsRemaining <= 2 * 60
}
