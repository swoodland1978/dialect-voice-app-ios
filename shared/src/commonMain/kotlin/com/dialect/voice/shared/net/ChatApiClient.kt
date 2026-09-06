package com.dialect.voice.shared.net

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

// Typed wrapper around the two Cloud Functions this app actually calls - request/response
// shapes copied verbatim from functions/src/functions/chatCompletion.ts and
// synthesizeSpeech.ts so the two stay honest with each other. voiceId/systemPrompt content
// (Dialects.kt, PromptBuilder.kt) lives client-side same as on Android; the backend is
// dialect-agnostic and just relays whatever prompt/voice it's given.
//
// Methods throw (see FirebaseCallableClient's header comment on why, not return Result<T>)
// so they cross into Swift as plain `async throws` calls.
class ChatApiClient(private val callable: FirebaseCallableClient) {

    private val json = Json { ignoreUnknownKeys = true }

    // chatCompletion.ts: { userText, systemPrompt } -> { text }. Metered against the text
    // balance server-side; throws FirebaseCallableException(status = "resource-exhausted",
    // message = "no_text_credit") when that balance is spent.
    @Throws(FirebaseCallableException::class, kotlin.coroutines.cancellation.CancellationException::class)
    suspend fun chatCompletion(userText: String, systemPrompt: String): String {
        val request = ChatCompletionRequest(userText, systemPrompt)
        val requestJson = json.encodeToJsonElement(ChatCompletionRequest.serializer(), request)
        val result = callable.call("chatCompletion", requestJson)
        return json.decodeFromJsonElement(ChatCompletionResponse.serializer(), result).text
    }

    // synthesizeSpeech.ts: { text, voiceId } -> { audioBase64, remainingSeconds }. Metered
    // against the voice balance server-side; throws FirebaseCallableException(status =
    // "resource-exhausted", message = "no_credit") when that balance is spent.
    @Throws(FirebaseCallableException::class, kotlin.coroutines.cancellation.CancellationException::class)
    suspend fun synthesizeSpeech(text: String, voiceId: String): SynthesizeSpeechResult {
        val request = SynthesizeSpeechRequest(text, voiceId)
        val requestJson = json.encodeToJsonElement(SynthesizeSpeechRequest.serializer(), request)
        val result = callable.call("synthesizeSpeech", requestJson)
        val response = json.decodeFromJsonElement(SynthesizeSpeechResponse.serializer(), result)
        return SynthesizeSpeechResult(audioBase64 = response.audioBase64, remainingSeconds = response.remainingSeconds)
    }
}

data class SynthesizeSpeechResult(val audioBase64: String, val remainingSeconds: Int)

@Serializable
private data class ChatCompletionRequest(val userText: String, val systemPrompt: String)

@Serializable
private data class ChatCompletionResponse(val text: String)

@Serializable
private data class SynthesizeSpeechRequest(val text: String, val voiceId: String)

@Serializable
private data class SynthesizeSpeechResponse(val audioBase64: String, val remainingSeconds: Int)
