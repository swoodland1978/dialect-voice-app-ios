// Shared KMP module - the "brains" of WhyAI iOS: dialect data, prompt building, usage/credit
// math, and the network client contract. Platform UI (SwiftUI) and platform auth/networking
// glue live outside this module.
//
// Target notes (see STATUS.md for the full story): iosArm64/iosSimulatorArm64/iosX64 are
// declared below because that's the real shape of this module once it's opened in Xcode, but
// this development machine has no Xcode/iOS SDK installed - only Command Line Tools - so those
// targets cannot actually be compiled or linked here. The `jvm()` target exists purely so
// commonMain has somewhere it can genuinely compile and run unit tests on *this* machine; it
// ships in no app and is dev/verification tooling only, not part of the iOS product surface.
plugins {
    kotlin("multiplatform")
    kotlin("plugin.serialization")
}

kotlin {
    jvm {
        // Verification-only target - see file header. Not part of the shipped iOS app.
        testRuns["test"].executionTask.configure { useJUnitPlatform() }
    }

    iosX64()
    iosArm64()
    iosSimulatorArm64()

    applyDefaultHierarchyTemplate()

    targets.withType<org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeTarget> {
        binaries.framework {
            baseName = "Shared"
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("io.ktor:ktor-client-core:2.3.12")
                implementation("io.ktor:ktor-client-content-negotiation:2.3.12")
                implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.12")
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
            }
        }
        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
            }
        }
        val jvmMain by getting {
            dependencies {
                // Only ever exercised by jvmTest on this dev machine - see file header.
                implementation("io.ktor:ktor-client-cio:2.3.12")
            }
        }
        val jvmTest by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
                implementation("io.ktor:ktor-client-mock:2.3.12")
            }
        }
        val iosMain by getting {
            dependencies {
                implementation("io.ktor:ktor-client-darwin:2.3.12")
            }
        }
    }
}
