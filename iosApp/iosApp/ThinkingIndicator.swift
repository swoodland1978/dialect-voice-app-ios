import SwiftUI

// Ported from the Android app's ThinkingIndicator: cycles "." -> ".." -> "..." -> "...." ->
// "....." and loops for as long as `isThinking` stays true, so a slow reply still looks alive.
struct ThinkingIndicator: View {
    var isThinking: Bool

    private let steps = [".", "..", "...", "....", "....."]
    @State private var stepIndex = 0
    private let clock = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if isThinking {
                Text(steps[stepIndex])
                    .font(.title2.weight(.bold))
                    .foregroundColor(Palette.primary)
            }
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .onReceive(clock) { _ in
            guard isThinking else { return }
            stepIndex = (stepIndex + 1) % steps.count
        }
        .onChange(of: isThinking) { thinking in
            if thinking { stepIndex = 0 }
        }
    }
}
