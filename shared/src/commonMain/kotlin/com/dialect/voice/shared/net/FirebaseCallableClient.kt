package com.dialect.voice.shared.net

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull

// Talks to the existing regional-dialect-ccd37 Cloud Functions (chatCompletion,
// synthesizeSpeech, ...) using the Firebase callable-function HTTP protocol directly -
// {"data": ...} in, {"result": ...} or {"error": {...}} out - rather than pulling in the
// Firebase iOS SDK. Same backend the Android app calls; this is a from-scratch client
// speaking the wire protocol, since the officially recommended path for Firebase on Kotlin
// Multiplatform's iOS targets is CocoaPods/SwiftPM integration of the native SDK, which
// needs Xcode to resolve and build - unavailable on this dev machine (see STATUS.md). This
// approach only needs a bearer ID token, which can come from any source (including a
// GitLive-style multiplatform Firebase Auth wrapper, or the native SDK once this is built in
// Xcode) - it doesn't lock the caller into how auth itself is obtained.
//
// Throws rather than returning Result<T>: kotlin.Result doesn't cross the Kotlin/Native ->
// Swift boundary cleanly (a well-known rough edge - it isn't a normal exported type), while
// a suspend fun marked @Throws(...) is Kotlin Multiplatform's documented, standard shape for
// becoming a plain Swift `async throws` call. CancellationException has to be listed
// alongside the real error type on every such annotation, or the compiler rejects it - a
// suspend fun can always be cancelled, so it's always a possible thrown type here.
class FirebaseCallableClient(
    private val httpClient: HttpClient,
    private val region: String,
    private val projectId: String,
    private val idTokenProvider: suspend () -> String?
) {
    private val json = Json { ignoreUnknownKeys = true }

    private fun functionUrl(name: String) = "https://$region-$projectId.cloudfunctions.net/$name"

    @Throws(FirebaseCallableException::class, kotlin.coroutines.cancellation.CancellationException::class)
    suspend fun call(functionName: String, data: JsonElement): JsonElement {
        val token = idTokenProvider()
            ?: throw FirebaseCallableException("unauthenticated", "Sign in required")

        val response = try {
            httpClient.post(functionUrl(functionName)) {
                contentType(ContentType.Application.Json)
                header("Authorization", "Bearer $token")
                setBody(json.encodeToString(CallableRequest.serializer(), CallableRequest(data)))
            }
        } catch (e: Exception) {
            throw FirebaseCallableException("unavailable", e.message ?: "Network request failed")
        }

        val bodyText: String = response.body()
        // Ktor does NOT throw on a non-2xx response by default (that needs the expectSuccess
        // plugin config) - status has to be checked explicitly, or a thrown HttpsError's
        // {"error": {...}} body silently gets misread as a "successful" response with no
        // "result" field. Caught by ChatApiClientTest's error-path test before this ever
        // reached production.
        if (!response.status.isSuccess()) {
            throw parseCallableError(bodyText)
        }
        return try {
            json.decodeFromString(CallableSuccessResponse.serializer(), bodyText).result
        } catch (e: Exception) {
            throw FirebaseCallableException("internal", "Malformed response: ${e.message}")
        }
    }

    private fun parseCallableError(bodyText: String): FirebaseCallableException {
        return try {
            val parsed = json.decodeFromString(CallableErrorEnvelope.serializer(), bodyText)
            FirebaseCallableException(parsed.error.status ?: "unknown", parsed.error.message)
        } catch (e: Exception) {
            FirebaseCallableException("unknown", bodyText)
        }
    }
}

// Mirrors the resource-exhausted "no_credit" / "no_text_credit" HttpsError codes thrown by
// chatCompletion.ts / synthesizeSpeech.ts, so callers can branch on `status` (e.g. show the
// paywall) without string-matching `message`.
class FirebaseCallableException(val status: String, message: String) : Exception(message)

@Serializable
private data class CallableRequest(val data: JsonElement)

@Serializable
private data class CallableSuccessResponse(val result: JsonElement = JsonNull)

@Serializable
private data class CallableErrorEnvelope(val error: CallableErrorBody)

@Serializable
private data class CallableErrorBody(
    val message: String,
    val status: String? = null,
    @SerialName("details") val details: JsonElement? = null
)
