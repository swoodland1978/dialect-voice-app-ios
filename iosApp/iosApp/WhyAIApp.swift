import SwiftUI

@main
struct WhyAIApp: App {
    @StateObject private var auth = AuthController()
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            Group {
                if splashDone || skipSplash {
                    RootView()
                        .environmentObject(auth)
                        .transition(.opacity)
                } else {
                    SplashView { withAnimation { splashDone = true } }
                }
            }
            .onAppear {
                // Screenshot/UI-test hook: skip the sign-in gate.
                if ProcessInfo.processInfo.environment["BYPASS_AUTH"] == "1" {
                    auth.continueWithoutSignIn()
                }
            }
        }
    }

    private var skipSplash: Bool {
        ProcessInfo.processInfo.environment["BYPASS_AUTH"] == "1"
    }
}

// Sign-in gate: the whole app sits behind auth (usage/credit is per account), same as the
// Android app. No anonymous fallback.
struct RootView: View {
    @EnvironmentObject var auth: AuthController

    var body: some View {
        switch auth.state {
        case .signedIn:
            ContentView(auth: auth)
        case .signedOut, .signingIn:
            SignInView()
        }
    }
}
