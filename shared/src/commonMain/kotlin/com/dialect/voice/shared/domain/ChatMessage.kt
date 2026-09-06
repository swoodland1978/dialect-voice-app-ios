package com.dialect.voice.shared.domain

// A single turn in the conversation, as held in memory client-side. Audio playback/caching
// is inherently platform-specific (AVAudioPlayer on iOS vs MediaPlayer on Android) so this
// only carries the state a platform player needs to react to, not a file handle itself.
data class ChatMessage(
    val id: String,
    val role: MessageRole,
    val text: String,
    val dialect: String? = null,
    val audioState: AudioState = AudioState.NONE,
    val status: MessageStatus = MessageStatus.DONE,
    val errorMessage: String? = null,
    val createdAtEpochMs: Long = 0L
)

enum class MessageRole { USER, ASSISTANT }

enum class MessageStatus { PENDING, DONE, ERROR }

// Audio is synthesized lazily (only once needed) since TTS is the expensive API call.
enum class AudioState { NONE, SYNTHESIZING, READY, PLAYING, ERROR, NO_CREDIT }

enum class RecordingState { IDLE, RECORDING, TRANSCRIBING }
