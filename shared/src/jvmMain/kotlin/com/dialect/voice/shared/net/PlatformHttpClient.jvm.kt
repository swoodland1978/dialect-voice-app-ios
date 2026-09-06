package com.dialect.voice.shared.net

import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

// jvmMain exists only so this dev machine (no Xcode/iOS SDK) can compile and unit-test
// commonMain for real - see shared/build.gradle.kts header. Never shipped in the iOS app.
actual fun createPlatformHttpClient(): HttpClient = HttpClient(CIO) {
    install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
}
