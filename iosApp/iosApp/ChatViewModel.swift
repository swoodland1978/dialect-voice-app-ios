import Foundation
import Shared

// Phase 1: text chat + the visual shell (mascot / waveform). Voice recording, transcription
// and TTS playback are phase 2 - the amplitude/recording state here is scaffolding for that,
// currently only ever driven by `isThinking`.
//
// Auth: the shared module's makeChatApiClient wants `() -> String?` returning an
// already-cached Firebase ID token. We pull it from AuthController, which does Sign in with
// Apple -> Firebase REST exchange out of band.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var dialects: [Dialect] = SharedApi.shared.enabledDialects
    @Published var selectedDialect: Dialect?
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private unowned let auth: AuthController

    private lazy var apiClient: ChatApiClient = SharedApi.shared.makeChatApiClient(
        idTokenProvider: { [weak self] in self?.auth.currentIdToken }
    )

    init(auth: AuthController) {
        self.auth = auth
        selectedDialect = dialects.first
    }

    /// Most recent question the user asked - the one bit of transcript the voice-only design
    /// keeps on screen (see Android's LastQuestion).
    var lastQuestion: String? {
        messages.last(where: { $0.role == MessageRole.user })?.text
    }

    var isThinking: Bool { isLoading }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let dialect = selectedDialect else { return }
        inputText = ""

        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: .user,
            text: text,
            dialect: dialect.id,
            audioState: .none,
            status: .done,
            errorMessage: nil,
            createdAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))
        isLoading = true

        Task {
            await auth.refreshIfNeeded()
            let systemPrompt = SharedApi.shared.buildSystemPrompt(dialect: dialect)
            do {
                let replyText = try await apiClient.chatCompletion(userText: text, systemPrompt: systemPrompt)
                self.isLoading = false
                self.messages.append(ChatMessage(
                    id: UUID().uuidString,
                    role: .assistant,
                    text: replyText,
                    dialect: dialect.id,
                    audioState: .none,
                    status: .done,
                    errorMessage: nil,
                    createdAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000)
                ))
            } catch {
                self.isLoading = false
                self.lastError = error.localizedDescription
            }
        }
    }
}
