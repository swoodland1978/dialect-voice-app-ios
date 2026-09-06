package com.dialect.voice.shared.net

import io.ktor.client.HttpClient
import io.ktor.client.engine.darwin.Darwin
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

// Compiler-verified: `./gradlew :shared:compileKotlinIosSimulatorArm64` compiles this for
// real (Kotlin/Native's own bundled toolchain, no Xcode needed for that step - see
// STATUS.md). Not yet linked/run.
actual fun createPlatformHttpClient(): HttpClient = HttpClient(Darwin) {
    install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
}
