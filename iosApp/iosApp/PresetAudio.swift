import Foundation

// Bundled on-device audio for the moments we speak without hitting the paid TTS backend:
// first app open, switching accent, signing out. Ported from the Android app's
// audio/PresetAudio.kt (welcome / switch / goodbye only for now - the noCredit and easter-egg
// clips there tie into the credit/paywall system, which isn't wired on iOS yet).
//
// `text` isn't shown anywhere (the UI is voice-only) - it's the source-of-truth transcript
// the mp3 must actually say, kept here for reference. Files live in iosApp/iosApp/PresetAudio/
// and are copied into the bundle by generate_xcodeproj.rb.
enum PresetAudio {
    struct Clips {
        let welcome: String
        let switchTo: String
        let goodbye: String
    }

    /// Keyed by dialect id. Only the ENABLED_DIALECT_IDS from the shared module have clips.
    static let byDialect: [String: Clips] = [
        "geordie": Clips(
            welcome: "welcome_geordie",   // "Now then, welcome to WhyAI - howay, what can I do for ya?"
            switchTo: "switch_geordie",   // "Reet, you're listening to Geordie now, pet."
            goodbye: "goodbye_geordie"    // "Reet, I'm off then - ta-ra, pet."
        ),
        "glaswegian": Clips(
            welcome: "welcome_glaswegian",
            switchTo: "switch_glaswegian", // "Right, yer listening tae Glaswegian noo, pal."
            goodbye: "goodbye_glaswegian"
        ),
        "scouse": Clips(
            welcome: "welcome_scouse",
            switchTo: "switch_scouse",     // "Sound - you're listening to Scouse now, la."
            goodbye: "goodbye_scouse"
        ),
        "cockney": Clips(
            welcome: "welcome_cockney",
            switchTo: "switch_cockney",    // "You're now earwigging Cockney, me old china."
            goodbye: "goodbye_cockney"
        ),
        "australian": Clips(
            welcome: "welcome_australian",
            switchTo: "switch_australian", // "Righto, you're listening to Australian now, mate."
            goodbye: "goodbye_australian"
        ),
    ]
}
