package com.dialect.voice.shared

import com.dialect.voice.shared.net.ChatApiClient
import com.dialect.voice.shared.net.FirebaseCallableClient
import com.dialect.voice.shared.net.FirebaseCallableException
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class ChatApiClientTest {

    private fun clientWith(mockEngine: MockEngine) = HttpClient(mockEngine) {
        install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
    }

    // Proves the request this client sends actually matches the Firebase callable protocol
    // ({"data": {...}}) that chatCompletion.ts expects on the other end, and that a
    // successful {"result": {...}} response round-trips correctly - real wire-format
    // verification without needing a live backend.
    @Test
    fun chatCompletionSendsCallableShapeAndParsesResult() = runTest {
        var capturedBody = ""
        val engine = MockEngine { request ->
            capturedBody = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """{"result":{"text":"alreet mate"}}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }
        val api = ChatApiClient(
            FirebaseCallableClient(clientWith(engine), "us-central1", "regional-dialect-ccd37") { "fake-token" }
        )

        val text = api.chatCompletion("hello", "system prompt")

        assertEquals("alreet mate", text)
        assertTrue(capturedBody.contains("\"userText\":\"hello\""))
        assertTrue(capturedBody.contains("\"systemPrompt\":\"system prompt\""))
        assertTrue(capturedBody.startsWith("{\"data\":"), "must wrap the payload in {\"data\": ...} per the callable protocol")
    }

    // Proves a thrown HttpsError("resource-exhausted", "no_text_credit") on the backend -
    // which arrives as a non-2xx response with an {"error": {...}} body - surfaces as a
    // FirebaseCallableException callers can branch on by status, not just a generic failure.
    @Test
    fun surfacesCallableErrorStatusOnFailure() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"error":{"message":"no_text_credit","status":"resource-exhausted"}}""",
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }
        val api = ChatApiClient(
            FirebaseCallableClient(clientWith(engine), "us-central1", "regional-dialect-ccd37") { "fake-token" }
        )

        val error = assertFailsWith<FirebaseCallableException> {
            api.chatCompletion("hello", "system prompt")
        }
        assertEquals("resource-exhausted", error.status)
        assertEquals("no_text_credit", error.message)
    }

    @Test
    fun noIdTokenThrowsUnauthenticatedWithoutMakingARequest() = runTest {
        var requestMade = false
        val engine = MockEngine {
            requestMade = true
            respond(content = "{}", status = HttpStatusCode.OK)
        }
        val api = ChatApiClient(
            FirebaseCallableClient(clientWith(engine), "us-central1", "regional-dialect-ccd37") { null }
        )

        val error = assertFailsWith<FirebaseCallableException> {
            api.chatCompletion("hello", "system prompt")
        }
        assertEquals("unauthenticated", error.status)
        assertTrue(!requestMade, "should fail fast on a missing token, not still hit the network")
    }
}
