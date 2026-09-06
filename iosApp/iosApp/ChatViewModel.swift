import Foundation
import Shared

// UNVERIFIED - see STATUS.md. No Swift toolchain on this dev machine to compile this
// against the real generated Shared.framework header, so the exact `SharedApi.shared...`
// call shapes below are written from the documented, standard Kotlin/Native `object` ->
// Swift `.shared` export convention, not confirmed against a real header. First thing to
// build once this repo is opened in Xcode.
//
// Auth is intentionally still a TODO: SharedApi.makeChatApiClient takes an idTokenProvider
// closure so this view model can plug in whichever Firebase Auth path the iOS app ends up
// using (native Firebase iOS SDK via CocoaPods, or a multiplatform wrapper) once that
// decision is made on a machine that can actually run Xcode/CocoaPods - see STATUS.md.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var dialects: [Dialect] = SharedApi.shared.enabledDialects
    @Published var selectedDialect: Dialect?
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private lazy var apiClient: ChatApiClient = SharedApi.shared.makeChatApiClient(
        idTokenProvider: {
            // TODO: return a real Firebase ID token once auth is wired up.
            return nil
        }
    )

    init() {
        selectedDialect = dialects.first
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let dialect = selectedDialect else { return }
        inputText = ""

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            text: text,
            dialect: dialect.id,
            audioState: .none,
            status: .done,
            errorMessage: nil,
            createdAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000)
        )
        messages.append(userMessage)
        isLoading = true

        Task {
            let systemPrompt = SharedApi.shared.buildSystemPrompt(dialect: dialect)
            do {
                // chatCompletion is @Throws(FirebaseCallableException::class) in Kotlin,
                // which is Kotlin Multiplatform's standard shape for exporting a suspend fun
                // as a plain Swift `async throws` call (see ChatApiClient's header comment).
                let replyText = try await apiClient.chatCompletion(userText: text, systemPrompt: systemPrompt)
                await MainActor.run {
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
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    // A FirebaseCallableException carries `status` (e.g. "resource-exhausted"
                    // for no_text_credit) - once bridged to Swift as NSError this is likely
                    // `.userInfo["KotlinException"]` or a custom NSError domain/code; exact
                    // shape TBD once this compiles for real (see file header). For now, show
                    // the message and let the paywall-branching be a follow-up.
                    self.lastError = error.localizedDescription
                }
            }
        }
    }
}
