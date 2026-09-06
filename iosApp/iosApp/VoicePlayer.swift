import Foundation
import AVFoundation

// Plays the TTS audio returned by SharedApi.synthesizeSpeech (base64), polling playback level
// so the mascot / waveform pulse with the actual voice - the iOS equivalent of the Android
// app's Visualizer hook in ChatViewModel.attachVisualizer.
@MainActor
final class VoicePlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var amplitude: Double = 0

    private var player: AVAudioPlayer?
    private var meterTimer: Timer?
    private var onFinish: (() -> Void)?

    /// `audioBase64` is the `SynthesizeSpeechResult.audioBase64` field (mp3 payload).
    func play(base64 audioBase64: String, onFinish: @escaping () -> Void) {
        stop()
        guard let data = Data(base64Encoded: audioBase64) else {
            onFinish()
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)

            let p = try AVAudioPlayer(data: data)
            p.isMeteringEnabled = true
            p.delegate = self
            guard p.play() else { onFinish(); return }

            player = p
            self.onFinish = onFinish
            isPlaying = true
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task { @MainActor [weak self] in self?.sampleLevel() }
            }
        } catch {
            onFinish()
        }
    }

    func stop() {
        meterTimer?.invalidate()
        meterTimer = nil
        amplitude = 0
        if player != nil {
            player?.stop()
            player = nil
            isPlaying = false
        }
        onFinish = nil
    }

    private func sampleLevel() {
        guard let player else { return }
        player.updateMeters()
        amplitude = AudioLevel.normalized(fromPower: player.averagePower(forChannel: 0))
    }
}

extension VoicePlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            let finish = self.onFinish
            self.stop()
            finish?()
        }
    }
}
