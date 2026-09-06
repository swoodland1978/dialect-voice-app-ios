# WhyAI - iOS

The iOS version of WhyAI (the Android dialect voice assistant app, `dialect-voice-app-kotlin`)
- a separate, standalone repo with entirely new code. It shares nothing with the Android
repo except the product itself: the same Firebase backend (`regional-dialect-ccd37`), the
same dialect personas/easter eggs, the same idea.

**Read [STATUS.md](STATUS.md) first** - it says exactly what's real (compiler-verified) here
versus written-but-unconfirmed, and the one concrete thing needed to move past that line.

## Layout

- `shared/` - Kotlin Multiplatform module: dialect data, prompt building, usage math, and the
  network client that talks to the existing Cloud Functions backend. `commonMain` +
  `iosMain` (real target) + `jvmMain`/`jvmTest` (dev-machine-only verification target, not
  shipped - see `shared/build.gradle.kts`).
- `iosApp/` - the SwiftUI app shell: `project.yml` (XcodeGen spec - generates the
  `.xcodeproj`, not hand-written) + Swift sources.

## Building

Needs a Mac with Xcode installed (not just Command Line Tools) and, ideally,
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```
brew install xcodegen
cd iosApp && xcodegen generate && open iosApp.xcodeproj
```

Building the app target runs `:shared:embedAndSignAppleFrameworkForXcode` automatically
(see `iosApp/project.yml`), which builds the Kotlin shared module and embeds it as
`Shared.framework` before Swift compiles.
