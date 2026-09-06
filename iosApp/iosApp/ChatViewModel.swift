import Foundation
import Combine
import AVFoundation
import Shared

// Phase 2: text + voice. Records a question -> Apple Speech transcription -> chatCompletion ->
// synthesizeSpeech -> plays the reply, with the mascot / waveform driven by real mic and
// playback levels. Ported from the Android app's ChatViewModel (minus preset greeting clips,
// easter eggs, and the Firestore credit banner, which have no iOS backend support yet).
//
// Auth: makeChatApiClient wants `() -> String?` returning a cached Firebase ID token, pulled
// from AuthController (Sign in with Apple -> Firebase REST exchange, out of band).
@MainActor
final class ChatViewModel: ObservableObject {
    enum RecordingState { case idle, recording, transcribing }

    @Published var dialects: [Dialect] = SharedApi.shared.enabledDialects
    @Published var selectedDialect: Dialect?
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    @Published private(set) var recordingState: RecordingState = .idle
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var playbackAmplitude: Double = 0
    @Published private(set) var recordingAmplitude: Double = 0
    @Published private(set) var accountState: AccountState = .unknown

    private unowned let auth: AuthController
    private let recorder = VoiceRecorder()
    private let player = VoicePlayer()

    private lazy var apiClient: ChatApiClient = SharedApi.shared.makeChatApiClient(
        idTokenProvider: { [weak self] in self?.auth.currentIdToken }
    )

    private let dialectDefaultsKey = "selected_dialect"

    init(auth: AuthController) {
        self.auth = auth

        let savedId = UserDefaults.standard.string(forKey: dialectDefaultsKey)
        selectedDialect = dialects.first(where: { $0.id == savedId }) ?? dialects.first

        recorder.$amplitude.assign(to: &$recordingAmplitude)
        player.$amplitude.assign(to: &$playbackAmplitude)
        player.$isPlaying.assign(to: &$isSpeaking)

        // Free, on-device greeting - never touches the paid TTS backend (Android does the
        // same in ChatViewModel.init -> playPresetGreeting).
        if let id = selectedDialect?.id, let clips = PresetAudio.byDialect[id] {
            player.playBundle(clips.welcome)
        }
    }

    /// Picks a dialect and speaks its "you're listening to X now" line (Android: setDialect).
    func selectDialect(_ dialect: Dialect) {
        guard dialect.id != selectedDialect?.id else { return }
        selectedDialect = dialect
        UserDefaults.standard.set(dialect.id, forKey: dialectDefaultsKey)
        if let clips = PresetAudio.byDialect[dialect.id] {
            player.playBundle(clips.switchTo)
        }
    }

    /// Speaks the current dialect's goodbye line, then runs `completion` (Android: playGoodbye).
    func signOut(then completion: @escaping () -> Void) {
        guard let id = selectedDialect?.id, let clips = PresetAudio.byDialect[id] else {
            completion()
            return
        }
        player.playBundle(clips.goodbye, onFinish: completion)
    }

    /// Most recent question the user asked - the one bit of transcript the voice-only design
    /// keeps on screen (see Android's LastQuestion).
    var lastQuestion: String? {
        messages.last(where: { $0.role == MessageRole.user })?.text
    }

    var isThinking: Bool { isLoading || recordingState == .transcribing }

    /// Pull the latest voice/text credit from Firestore (call on appear and after each turn).
    func refreshAccountState() async {
        guard let token = auth.currentIdToken, let uid = auth.userId else { return }
        if let state = await UsageService.fetch(idToken: token, uid: uid) {
            accountState = state
        }
    }

    // MARK: - Mascot tap: interrupt playback, else start/stop listening

    func mascotTapped() {
        switch true {
        case isThinking:                    break
        case isSpeaking:                    player.stop()
        case recordingState == .recording:  stopRecording()
        default:                            startRecording()
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard recordingState == .idle else { return }
        player.stop()
        Task {
            guard await ensureMicAndSpeechPermission() else {
                lastError = "Microphone or speech permission denied"
                return
            }
            do {
                try recorder.start()
                recordingState = .recording
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func stopRecording() {
        guard recordingState == .recording else { return }
        let file = recorder.stop()
        recordingState = .transcribing
        Task {
            await transcribeAndSend(file)
            recordingState = .idle
        }
    }

    private func transcribeAndSend(_ file: URL?) async {
        guard let file else {
            lastError = "No audio captured"
            return
        }
        do {
            let transcript = try await SpeechTranscriber.transcribe(fileURL: file)
            try? FileManager.default.removeItem(at: file)
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { send(text: trimmed) }
        } catch {
            lastError = "Couldn't transcribe that"
        }
    }

    // MARK: - Send + speak

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        send(text: text)
    }

    private func send(text: String) {
        guard let dialect = selectedDialect else { return }

        messages.append(ChatMessage(
            id: UUID().uuidString, role: .user, text: text, dialect: dialect.id,
            audioState: .none, status: .done, errorMessage: nil,
            createdAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000)
        ))
        isLoading = true
        lastError = nil

        Task {
            await auth.refreshIfNeeded()
            let systemPrompt = SharedApi.shared.buildSystemPrompt(dialect: dialect)
            do {
                let replyText = try await apiClient.chatCompletion(userText: text, systemPrompt: systemPrompt)
                messages.append(ChatMessage(
                    id: UUID().uuidString, role: .assistant, text: replyText, dialect: dialect.id,
                    audioState: .none, status: .done, errorMessage: nil,
                    createdAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000)
                ))
                isLoading = false
                await speak(replyText, dialect: dialect)
                await refreshAccountState()
            } catch {
                isLoading = false
                lastError = error.localizedDescription
            }
        }
    }

    private func speak(_ text: String, dialect: Dialect) async {
        do {
            let result = try await apiClient.synthesizeSpeech(text: text, voiceId: dialect.elevenLabsVoiceId)
            await withCheckedContinuation { cont in
                player.play(base64: result.audioBase64) { cont.resume() }
            }
        } catch {
            // Text reply is already on screen; a TTS failure just means no audio this turn.
            lastError = "Couldn't play the voice reply"
        }
    }

    // MARK: - Permissions

    private func ensureMicAndSpeechPermission() async -> Bool {
        let mic = await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
        guard mic else { return false }
        return await SpeechTranscriber.requestAuthorization()
    }
}
