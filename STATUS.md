# Status

## Update 2026-09-06: builds and runs in the iOS Simulator

Xcode is now installed on this Mac (**Xcode 14.0.1** - the last line that runs on macOS 12
Monterey, the ceiling for this 2015 MacBook Pro). The whole path below now works:

- `./gradlew :shared:jvmTest` - still 10/10.
- `./gradlew :shared:linkDebugFrameworkIosX64` - **links clean.** The old "actual wall" is
  gone. Kotlin 2.2.10's Kotlin/Native link step works fine against Xcode 14.0.1 - no Kotlin
  downgrade needed. (Target is `iosX64`, not `iosSimulatorArm64`: this Mac is Intel.)
- **The SwiftUI app builds and launches in the iPhone 14 / iOS 16.0 simulator.** The dialect
  picker populates from the shared module (`enabledDialects` bridges correctly), the chat
  shell renders. Sending a message hits the auth TODO (no token -> "unauthenticated") - the
  network path itself is still untested end-to-end, blocked on auth.

Fixes that were needed to get there:
- `SharedApi.makeChatApiClient` took `suspend () -> String?`. Kotlin/Native exports a suspend
  *function-type parameter* as a protocol Swift can't satisfy with a closure, so the Swift
  caller could never call it. Changed to a plain `() -> String?` (caller hands back an
  already-cached token); `FirebaseCallableClient` keeps its `suspend` provider internally.
- `ContentView.swift` used the `#Preview` macro (Xcode 15+). Reverted to a `PreviewProvider`.
- `iosApp/Info.plist` was missing `CFBundleIdentifier`/`CFBundleExecutable`/etc. - Xcode only
  auto-injects those with `GENERATE_INFOPLIST_FILE=YES`. Added them as `$(...)` build-setting
  refs.

Tooling notes:
- **XcodeGen can't be installed on macOS 12 anymore** (Homebrew dropped Monterey bottles;
  building from source needs Xcode 15.3). Replaced with `iosApp/generate_xcodeproj.rb`, which
  uses the `xcodeproj` Ruby gem (`gem install --user-install xcodeproj`) to generate
  `iosApp.xcodeproj` from the same intent as `project.yml`. Keep the two in sync.
- Build: `cd iosApp && ruby generate_xcodeproj.rb && open iosApp.xcodeproj`, or headless with
  `xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 14' build`.

### Phase 1 UI (later the same day): visual parity + Sign in with Apple

`ContentView.swift` was a bare text-chat shell; it's now the voice-first screen ported from
the Android app's `ui/ChatScreen.kt`. New Swift files: `Theme.swift`, `AnimatedMascot.swift`
(cap logo + 3 pulsing soundwave rings), `AudioWaveform.swift` (32-bar rolling strip),
`ThinkingIndicator.swift`, `SignInView.swift` (logo + Sign in with Apple), `AuthController.swift`
(Apple identity token -> Firebase Identity Toolkit REST exchange, no Firebase SDK),
`FirebaseConfig.swift`, `RootView` in `WhyAIApp.swift`. Logo asset copied from the Android
repo into `Assets.xcassets`. `iosApp.entitlements` adds `com.apple.developer.applesignin`.

Builds and runs in the simulator (sign-in screen + chat screen both verified via screenshot;
`BYPASS_AUTH=1` launch env skips the gate). Paywall is phase 3 (the "Buy credit" button is a
layout placeholder).

### Phase 2: voice

`VoiceRecorder.swift` (AVAudioRecorder -> m4a + level metering), `SpeechTranscriber.swift`
(on-device `SFSpeechRecognizer`, en-GB - the iOS choice; Android uses Whisper),
`VoicePlayer.swift` (plays `SharedApi.synthesizeSpeech`'s base64 mp3 via AVAudioPlayer +
metering), `AudioLevel.swift` (dBFS -> 0...1). `ChatViewModel` orchestrates:
record -> transcribe -> `chatCompletion` -> `synthesizeSpeech` -> play, with the mascot /
waveform now driven by real `recordingAmplitude` / `playbackAmplitude` and `isSpeaking`. Mic
button added to the input row; tapping the mascot starts/stops listening or interrupts
playback. `Info.plist` gained `NSSpeechRecognitionUsageDescription`.

Builds clean, runs without crashing, mic button present. The full voice round-trip can't be
exercised headless (no simulator mic input; backend calls need the auth config above) - needs
a device or completed Firebase/Apple setup to verify end to end.

**Sign in with Apple needs console config to actually authenticate** (only the user can do
this): (1) add an iOS app in the Firebase console for `regional-dialect-ccd37`, bundle id
`com.dialect.voice.ios`, download `GoogleService-Info.plist` into `iosApp/iosApp/`;
(2) enable the Apple auth provider in Firebase; (3) configure Sign in with Apple in the Apple
Developer account (needs paid Program membership). Until then the Apple step completes but no
Firebase token is issued - use "Continue without signing in" on the sign-in screen.

Everything from here down is the original pre-Xcode status, kept for context.

---

Written after a session of unattended work on this Mac, which had **no Xcode installed** -
only Xcode Command Line Tools (`xcode-select -p` -> `/Library/Developer/CommandLineTools`,
`xcrun --sdk iphoneos --show-sdk-path` fails, `xcodebuild -version` fails). That was a hard
ceiling on how "finished" anything iOS-shaped could be from there. This file says exactly what
that ceiling let through, verified for real, versus what's written but unconfirmed.

**Also worth knowing before installing Xcode here or anywhere:** this machine has ~1.9GB of
free disk space left (checked after Kotlin/Native's own toolchain download below used
~2.8GB). Xcode itself is a 15-40GB install. That's a separate, purely-disk-space blocker on
top of the "no Xcode at all" one.

## What's real (compiler-verified on this machine)

Kotlin/Native turns out to ship its own bundled toolchain (LLVM, a partial Apple-platform
sysroot with real Foundation/UIKit declarations) that doesn't need Xcode for straight
compilation - only the final link step does. So more got verified here than I expected
going in:

- `./gradlew :shared:jvmTest` - **10/10 tests pass.** Real unit tests, run for real, covering
  dialect data integrity, prompt building, the usage-estimate formula, and the network
  client's wire format (via a mock HTTP engine - see `ChatApiClientTest.kt`). One of these
  tests caught a genuine bug during this session: `FirebaseCallableClient` silently treated
  an HTTP error response as a success because Ktor doesn't throw on non-2xx by default. Fixed
  and reverified before moving on - not a claim, an actual before/after test run.
- `./gradlew :shared:compileKotlinIosSimulatorArm64` - **compiles clean.** This compiles the
  real `iosMain` source set (including `platform.Foundation` interop in `PlatformDate.ios.kt`
  and the Darwin Ktor engine in `PlatformHttpClient.ios.kt`) against Kotlin/Native's bundled
  Apple declarations. This is real compiler verification of the iOS-target Kotlin code, not
  just "looks right to me."
- `./gradlew :shared:linkDebugFrameworkIosSimulatorArm64` - **fails**, and this is the actual
  wall: `An error occurred during an xcrun execution... Failed command: /usr/bin/xcrun
  xcodebuild -version`. Producing the real `Shared.framework` an Xcode project would embed
  needs Xcode itself, not just Kotlin/Native's bundled toolchain.

## What's written but unverified

- All of `iosApp/` (the SwiftUI app shell) - no Swift compiler on this machine at all, so
  none of it has been built. Written to the standard, documented KMP+SwiftUI shape I'm
  confident in, with two things flagged inline as genuinely uncertain:
  - The exact Swift-facing API shape of `SharedApi` (the Kotlin `object` -> Swift `.shared`
    convention is standard and reliable; I can't confirm the exact generated names without a
    real `Shared.h`, which only gets generated by the link step above).
  - Whether `SharedApi.shared.enabledDialects` / `ChatMessage` etc. conform to
    `Equatable`/`Hashable` the way `ContentView.swift`'s `Picker` selection and `ForEach(id:)`
    assume - Kotlin data classes bridge their `equals`/`hashCode` to Swift, which usually
    makes this work, but "usually" isn't "confirmed."
  - `iosApp/project.yml` (XcodeGen spec) itself is unverified for the same reason - no
    XcodeGen on this machine to run it against.
- Auth is a deliberate TODO, not an oversight: `SharedApi.makeChatApiClient(idTokenProvider:)`
  takes a token-supplying closure and has no opinion on how that token is obtained. Wiring up
  real Firebase Auth (native SDK via CocoaPods/SwiftPM, or a multiplatform wrapper) is a
  decision that needs Xcode/CocoaPods to actually try, so it was left as a clean seam rather
  than guessed at.

## What's deliberately identical to the Android app

`shared/.../domain/Dialects.kt` is a verbatim port, not new code - the dialect personas and
easter eggs are the product content itself, not Android-specific logic, so this is the one
file meant to be a copy. Keep the two in sync by hand if either changes.
`shared/.../prompt/PromptBuilder.kt` mirrors `ChatViewModel.sendMessage()`'s three hints
(length, sparetime, current-affairs) - including the same "don't hard-code a specific office
holder" lesson from the Android side's history, pinned by a regression test
(`PromptBuilderTest.neverHardCodesASpecificOfficeHolder`).

## Next steps, in order

Steps 1-3 (get on a Mac with Xcode, generate the project, fix the first Swift build errors)
are **done** - see the 2026-09-06 update at the top. Remaining:

1. Wire up the auth path: **Sign in with Apple -> Firebase ID token** fed to
   `SharedApi.makeChatApiClient`'s `() -> String?` provider (return a cached token). This
   blocks every server call - everything else is ready to receive a real token.
2. Only after that: the actual UI work (mascot/waveform, matching the Android app's current
   voice-only redesign) - not started here at all; `ContentView.swift` is a bare functional
   shell, not a design pass.
