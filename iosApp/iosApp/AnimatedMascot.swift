import SwiftUI

// The centrepiece of the screen, ported from the Android app's AnimatedMascot: the WhyAI
// cap mascot with three soundwave rings pulsing behind it.
//   idle      -> slow "breathing" pulse
//   busy      -> fast small pulse (thinking / transcribing)
//   recording -> pulses with mic input level        (phase 2 - recordingAmplitude)
//   speaking  -> pulses with playback amplitude      (phase 2 - playbackAmplitude)
// A tap is the only control: start/stop listening, or interrupt playback.
struct AnimatedMascot: View {
    var isSpeaking: Bool = false
    var isRecording: Bool = false
    var isBusy: Bool = false
    var hasError: Bool = false
    var playbackAmplitude: Double = 0
    var recordingAmplitude: Double = 0
    var onTap: () -> Void = {}

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let amplitude = currentAmplitude(at: t)

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let baseRadius = min(size.width, size.height) / 2 * 0.42
                    for ring in 0..<3 {
                        let ringAmp = min(max(amplitude * (1 - Double(ring) * 0.18), 0), 1)
                        let radius = baseRadius * (1.25 + Double(ring) * 0.28 + ringAmp * 0.5)
                        let alpha = (0.30 - Double(ring) * 0.08) * (0.35 + amplitude)
                        let rect = CGRect(
                            x: center.x - radius, y: center.y - radius,
                            width: radius * 2, height: radius * 2
                        )
                        context.stroke(
                            Path(ellipseIn: rect),
                            with: .color(ringColor.opacity(min(max(alpha, 0), 1))),
                            lineWidth: 3
                        )
                    }
                }

                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .clipShape(Circle())
                    .scaleEffect(1 + amplitude * 0.2)
            }
            .frame(width: 280, height: 280)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityLabel(isRecording ? "Listening – tap to stop" : "Tap to talk")
        }
    }

    private var ringColor: Color {
        if hasError { return Palette.error }
        if isRecording { return Palette.recording }
        return Palette.primary
    }

    private func currentAmplitude(at t: TimeInterval) -> Double {
        // Reversing triangle waves standing in for Android's infiniteRepeatable(Reverse).
        let idlePulse   = triangle(t, period: 2.2)
        let busyPulse   = triangle(t, period: 0.42)
        let talkingPulse = 0.25 + 0.5 * triangle(t, period: 0.38)

        switch true {
        case isSpeaking:  return max(playbackAmplitude, talkingPulse)
        case isRecording: return recordingAmplitude
        case isBusy:      return busyPulse * 0.55
        default:          return idlePulse * 0.12
        }
    }

    /// 0→1→0 ramp with the given period in seconds.
    private func triangle(_ t: TimeInterval, period: Double) -> Double {
        let phase = (t.truncatingRemainder(dividingBy: period)) / period
        return phase < 0.5 ? phase * 2 : (1 - phase) * 2
    }
}
