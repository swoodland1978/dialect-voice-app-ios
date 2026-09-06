import Foundation

// Minimal Firebase project config, read from GoogleService-Info.plist in the app bundle.
// We only need two values because auth and networking both speak the Firebase REST wire
// protocol directly (no Firebase SDK) - see the shared module's FirebaseCallableClient and
// AuthController here.
//
// GoogleService-Info.plist is NOT in the repo. Download it from the Firebase console
// (project regional-dialect-ccd37 -> add an iOS app, bundle id com.dialect.voice.ios) and
// drop it in iosApp/iosApp/, then re-run generate_xcodeproj.rb. Until then, Sign in with
// Apple still runs but can't be exchanged for a Firebase token, so backend calls stay
// unauthenticated - the UI is fully navigable via the dev bypass on the sign-in screen.
struct FirebaseConfig {
    let apiKey: String
    let projectId: String

    var authDomain: String { "\(projectId).firebaseapp.com" }

    static let shared: FirebaseConfig? = {
        guard
            let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url),
            let apiKey = dict["API_KEY"] as? String,
            let projectId = dict["PROJECT_ID"] as? String
        else { return nil }
        return FirebaseConfig(apiKey: apiKey, projectId: projectId)
    }()
}
