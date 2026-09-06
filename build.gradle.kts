// Root project - no Android application module here deliberately. This repo is the iOS
// version of WhyAI: a Kotlin Multiplatform `shared` module (commonMain business logic +
// iosMain platform glue) consumed by a native SwiftUI app in iosApp/. The existing Android
// app (dialect-voice-app-kotlin) is a separate, untouched repo - nothing here depends on it
// or vice versa.
plugins {
    kotlin("multiplatform") version "2.2.10" apply false
    kotlin("plugin.serialization") version "2.2.10" apply false
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}
