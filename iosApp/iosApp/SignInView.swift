import SwiftUI
import AuthenticationServices

// Ported from the Android app's SignInScreen: badge (which carries the "WHY AI" wordmark, so
// no separate title), one line of copy, the sign-in button, version string.
//
// Sign in with Apple is built (see AuthController) but hidden until it's configured end to
// end: Apple provider enabled in Firebase + a real GoogleService-Info.plist + Sign in with
// Apple set up in the Apple Developer account. Flip `appleSignInEnabled` to true once that's
// done. Until then the dev sign-in (anonymous / email) is the way in.
struct SignInView: View {
    static let appleSignInEnabled = false

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

                if Self.appleSignInEnabled {
                    SignInWithAppleButton(.signIn) { request in
                        auth.configure(request)
                    } onCompletion: { result in
                        auth.handle(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(width: 260, height: 48)
                    .disabled(auth.state == .signingIn)
                } else {
                    devSignIn
                }

                if let error = auth.errorMessage {
                    Spacer().frame(height: 16)
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(Palette.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if Self.appleSignInEnabled {
                    Spacer().frame(height: 24)
                    DisclosureGroup("Dev sign-in", isExpanded: $showDev) { devSignIn }
                        .font(.footnote)
                        .foregroundColor(Palette.onSurfaceVariant)
                        .padding(.horizontal, 48)
                }

                Spacer().frame(height: 24)

                Text(appVersion)
                    .font(.caption2)
                    .foregroundColor(Palette.onSurfaceVariant)
            }
        }
    }

    private var devSignIn: some View {
        VStack(spacing: 10) {
            Button("Sign in anonymously") {
                Task { await auth.signInAnonymously() }
            }
            .disabled(auth.state == .signingIn)

            Divider().frame(maxWidth: 220)

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
        }
        .padding(.horizontal, 48)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(v) (\(b))"
    }
}
