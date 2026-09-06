package com.dialect.voice.shared.net

import io.ktor.client.HttpClient

// expect/actual so Swift never has to construct a Ktor HttpClient (or pick an engine) by
// hand - that would mean Ktor's own types crossing the Kotlin/Swift boundary, an interop
// shape this dev machine has no way to verify (see STATUS.md). Swift only ever calls
// SharedApi.shared.makeChatApiClient(idTokenProvider:); everything networking-related stays
// inside this module.
expect fun createPlatformHttpClient(): HttpClient
