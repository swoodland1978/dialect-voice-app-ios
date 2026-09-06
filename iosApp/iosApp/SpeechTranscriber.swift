import Foundation
import Speech

// On-device transcription via Apple's Speech framework (the platform choice for iOS - the
// Android app uses OpenAI Whisper, but that endpoint isn't in the shared module and Apple's
// recognizer is free, offline, and needs no key).
enum SpeechTranscriber {
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribes a recorded audio file. Throws on permission / recognition failure.
    static func transcribe(fileURL: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB")) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }
        recognizer.defaultTaskHint = .dictation

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let result, result.isFinal {
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    enum TranscriptionError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Speech recognition isn't available" }
    }
}
