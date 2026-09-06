import Foundation

// Shared helper for turning AVFoundation's dBFS power readings (-160...0) into the normalized
// 0...1 amplitude the mascot / waveform expect. Mirrors the intent of the Android app's
// RMS-based normalization in ChatViewModel.attachVisualizer - track moment-to-moment
// loudness, not peak, and expand the quiet end so ordinary speech visibly moves things.
enum AudioLevel {
    /// `power` is dBFS from `AVAudioRecorder/Player.averagePower(forChannel:)`.
    static func normalized(fromPower power: Float) -> Double {
        let floorDb: Float = -50            // treat anything below this as silence
        guard power > floorDb else { return 0 }
        let linear = (power - floorDb) / -floorDb          // 0...1 across the floor..0 range
        return min(max(pow(Double(linear), 0.7), 0), 1)    // expand the quiet end (Android used ^0.7 too)
    }
}
