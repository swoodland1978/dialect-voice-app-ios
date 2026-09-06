import SwiftUI

@main
struct WhyAIApp: App {
    @StateObject private var auth = AuthController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .onAppear {
                    // Screenshot/UI-test hook: skip the sign-in gate.
                    if ProcessInfo.processInfo.environment["BYPASS_AUTH"] == "1" {
                        auth.continueWithoutSignIn()
                    }
                }
        }
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
