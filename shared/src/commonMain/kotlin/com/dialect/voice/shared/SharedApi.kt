package com.dialect.voice.shared

import com.dialect.voice.shared.domain.DIALECTS
import com.dialect.voice.shared.domain.Dialect
import com.dialect.voice.shared.domain.ENABLED_DIALECT_IDS
import com.dialect.voice.shared.net.ChatApiClient
import com.dialect.voice.shared.net.FirebaseCallableClient
import com.dialect.voice.shared.net.createPlatformHttpClient
import com.dialect.voice.shared.prompt.PromptBuilder
import com.dialect.voice.shared.prompt.todayFormatted
import com.dialect.voice.shared.usage.estimateSeconds

// Single entry point for the Swift side of the app. Deliberately an `object` rather than
// top-level functions/vals: Kotlin/Native's Objective-C export turns an `object` into a
// predictable `SharedApi.shared.methodName()` surface in Swift, whereas file-level top-level
// declarations get name-mangled per source file in a way that's easy to get wrong by hand
// and, on this dev machine, impossible to double-check against a real generated header (that
// needs `linkDebugFrameworkIosSimulatorArm64`, which needs Xcode - see STATUS.md). Routing
// everything through one object keeps the Swift-facing API small and predictable.
object SharedApi {
    val enabledDialects: List<Dialect>
        get() = ENABLED_DIALECT_IDS.mapNotNull { DIALECTS[it] }

    fun dialectById(id: String): Dialect? = DIALECTS[id]

    fun today(): String = todayFormatted()

    fun buildSystemPrompt(dialect: Dialect): String =
        PromptBuilder.buildFullSystemPrompt(dialect.systemPrompt, today())

    fun estimateSeconds(text: String): Int = com.dialect.voice.shared.usage.estimateSeconds(text)

    // The HttpClient (Ktor, engine picked per-platform - see PlatformHttpClient.kt) is built
    // entirely inside this module so no Ktor type ever has to cross the Kotlin/Swift
    // boundary. idTokenProvider is expected to call whatever Firebase Auth wrapper the iOS
    // app ends up using - this module deliberately has no opinion on how a token is
    // obtained, only how it's used once it exists. See FirebaseCallableClient's own header.
    fun makeChatApiClient(idTokenProvider: suspend () -> String?): ChatApiClient =
        ChatApiClient(
            FirebaseCallableClient(
                createPlatformHttpClient(),
                region = "us-central1",
                projectId = "regional-dialect-ccd37",
                idTokenProvider = idTokenProvider
            )
        )
}
