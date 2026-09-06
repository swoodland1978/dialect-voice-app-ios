import SwiftUI
import AuthenticationServices

// Ported from the Android app's SignInScreen: badge (which carries the "WHY AI" wordmark, so
// no separate title), one line of copy, the sign-in button, version string. Android uses
// "Sign in with Google"; iOS uses Sign in with Apple.
struct SignInView: View {
    @EnvironmentObject var auth: AuthController
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDev = false
    @State private var devEmail = ""
    @State private var devPassword = ""

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

                // Dev sign-in - remove once Sign in with Apple + Firebase console config is
                // done. Email/password against a Firebase test user gets a real ID token so
                // the AI + voice backend can be tested on the simulator now.
                DisclosureGroup("Dev sign-in", isExpanded: $showDev) {
                    VStack(spacing: 10) {
                        Button("Sign in anonymously") {
                            Task { await auth.signInAnonymously() }
                        }
                        .disabled(auth.state == .signingIn)

                        Divider()

                        TextField("email", text: $devEmail)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        SecureField("password", text: $devPassword)
                            .textFieldStyle(.roundedBorder)
                        Button("Sign in with email") {
                            Task { await auth.signInWithEmail(devEmail, password: devPassword) }
                        }
                        .disabled(devEmail.isEmpty || devPassword.isEmpty || auth.state == .signingIn)

                        Button("Continue without signing in") {
                            auth.continueWithoutSignIn()
                        }
                        .font(.footnote)
                        .foregroundColor(Palette.onSurfaceVariant)
                    }
                    .padding(.top, 8)
                }
                .font(.footnote)
                .foregroundColor(Palette.onSurfaceVariant)
                .padding(.horizontal, 48)

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
