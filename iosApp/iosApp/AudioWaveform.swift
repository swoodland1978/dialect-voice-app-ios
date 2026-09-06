import SwiftUI
import Combine

// Bar-style waveform under the mascot, ported from the Android app's AudioWaveform: a short
// rolling history of the same amplitude signal driving the mascot's rings, so it reads as one
// continuous strip scrolling past rather than every bar jumping in lockstep.
struct AudioWaveform: View {
    var isSpeaking: Bool = false
    var isRecording: Bool = false
    var isBusy: Bool = false
    var playbackAmplitude: Double = 0
    var recordingAmplitude: Double = 0
    var barCount: Int = 32

    @StateObject private var sampler = WaveformSampler()

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(sampler.history.indices, id: \.self) { i in
                let level = sampler.history[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.4 + level * 0.6))
                    .frame(height: 4 + (36 - 4) * level)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 40)
        .onAppear { sampler.configure(barCount: barCount) }
        .onChange(of: isSpeaking) { sampler.inputs.isSpeaking = $0 }
        .onChange(of: isRecording) { sampler.inputs.isRecording = $0 }
        .onChange(of: isBusy) { sampler.inputs.isBusy = $0 }
        .onChange(of: playbackAmplitude) { sampler.inputs.playbackAmplitude = $0 }
        .onChange(of: recordingAmplitude) { sampler.inputs.recordingAmplitude = $0 }
    }

    private var color: Color { isRecording ? Palette.recording : Palette.primary }
}

// Samples the current amplitude every 55ms (matching Android's `delay(55)` loop) and keeps a
// fixed-length rolling history, so the strip scrolls smoothly instead of every bar snapping.
@MainActor
final class WaveformSampler: ObservableObject {
    struct Inputs {
        var isSpeaking = false
        var isRecording = false
        var isBusy = false
        var playbackAmplitude: Double = 0
        var recordingAmplitude: Double = 0
    }

    @Published private(set) var history: [Double] = Array(repeating: 0.05, count: 32)
    var inputs = Inputs()

    private var timer: AnyCancellable?
    private let start = Date()

    func configure(barCount: Int) {
        if history.count != barCount {
            history = Array(repeating: 0.05, count: barCount)
        }
        guard timer == nil else { return }
        timer = Timer.publish(every: 0.055, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let t = Date().timeIntervalSince(start)
        var next = history
        next.append(min(max(amplitude(at: t), 0), 1))
        if next.count > history.count { next.removeFirst(next.count - history.count) }
        history = next
    }

    private func amplitude(at t: TimeInterval) -> Double {
        let idlePulse = triangle(t, period: 2.2)
        let busyPulse = triangle(t, period: 0.42)
        let talkingPulse = 0.25 + 0.5 * triangle(t, period: 0.38)
        switch true {
        case inputs.isSpeaking:  return max(inputs.playbackAmplitude, talkingPulse)
        case inputs.isRecording: return inputs.recordingAmplitude
        case inputs.isBusy:      return busyPulse * 0.55
        default:                 return idlePulse * 0.12
        }
    }

    private func triangle(_ t: TimeInterval, period: Double) -> Double {
        let phase = (t.truncatingRemainder(dividingBy: period)) / period
        return phase < 0.5 ? phase * 2 : (1 - phase) * 2
    }
}
