import SwiftUI
import AuthenticationServices

// Ported from the Android app's SignInScreen: badge (which carries the "WHY AI" wordmark, so
// no separate title), one line of copy, the sign-in button, version string. Android uses
// "Sign in with Google"; iOS uses Sign in with Apple.
struct SignInView: View {
    @EnvironmentObject var auth: AuthController
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())

                Spacer().frame(height: 20)

                Text("Sign in to chat with a regional AI voice")
                    .font(.subheadline)
                    .foregroundColor(Palette.onSurfaceVariant)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 32)

                SignInWithAppleButton(.signIn) { request in
                    auth.configure(request)
                } onCompletion: { result in
                    auth.handle(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(width: 260, height: 48)
                .disabled(auth.state == .signingIn)

                if let error = auth.errorMessage {
                    Spacer().frame(height: 16)
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(Palette.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 24)

                // Dev bypass - remove once GoogleService-Info.plist + the Apple provider are
                // configured. Lets the chat UI be exercised on the simulator meanwhile.
                Button("Continue without signing in") {
                    auth.continueWithoutSignIn()
                }
                .font(.footnote)
                .foregroundColor(Palette.onSurfaceVariant)

                Spacer().frame(height: 24)

                Text(appVersion)
                    .font(.caption2)
                    .foregroundColor(Palette.onSurfaceVariant)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }
}
