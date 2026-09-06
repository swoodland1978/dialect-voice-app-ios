import SwiftUI

// Brief "hello" frame on cold launch - the mascot springs in on white, then hands off to the
// real UI. The Android app's WelcomeSplashScreen also plays a spoken greeting here; iOS has
// no preset audio clips, so this is visual only.
struct SplashView: View {
    var onFinished: () -> Void

    @State private var shown = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .clipShape(Circle())
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { onFinished() }
        }
    }
}
