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
                // Screenshot/UI-test hooks.
                let env = ProcessInfo.processInfo.environment
                if env["AUTO_ANON"] == "1" {
                    Task { await auth.signInAnonymously() }
                } else if env["BYPASS_AUTH"] == "1" {
                    auth.continueWithoutSignIn()
                }
            }
        }
    }

    private var skipSplash: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["BYPASS_AUTH"] == "1" || env["AUTO_ANON"] == "1"
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
