import Foundation

// The user's remaining voice / text credit, read straight from Firestore via its REST API
// (users/{uid} - creditSecondsRemaining, textSecondsRemaining). The Android app gets this
// from a live Firestore listener (UserRepository); iOS reads it on demand after each turn.
// No Firestore SDK - same "speak the wire protocol" approach as the rest of the app.
struct AccountState: Equatable {
    var voiceSecondsRemaining: Int
    var textSecondsRemaining: Int

    static let unknown = AccountState(voiceSecondsRemaining: -1, textSecondsRemaining: -1)

    var hasVoiceCredit: Bool { voiceSecondsRemaining > 0 }

    /// "12 min of voice credit left" / "45 sec ..." - matches the Android UsageBanner, which
    /// switches to seconds under a minute so "0 min left" never shows while credit remains.
    var voiceCreditLabel: String? {
        guard voiceSecondsRemaining > 0 else { return nil }
        if voiceSecondsRemaining < 60 {
            return "\(voiceSecondsRemaining) sec of voice credit left"
        }
        return "\(voiceSecondsRemaining / 60) min of voice credit left"
    }
}

enum UsageService {
    static func fetch(idToken: String, uid: String) async -> AccountState? {
        guard let project = FirebaseConfig.shared?.projectId else { return nil }
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/users/\(uid)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let fields = json?["fields"] as? [String: Any] else { return nil }
            return AccountState(
                voiceSecondsRemaining: intField(fields, "creditSecondsRemaining"),
                textSecondsRemaining: intField(fields, "textSecondsRemaining")
            )
        } catch {
            return nil
        }
    }

    private static func intField(_ fields: [String: Any], _ key: String) -> Int {
        guard let wrapper = fields[key] as? [String: Any],
              let s = wrapper["integerValue"] as? String else { return 0 }
        return Int(s) ?? 0
    }
}
