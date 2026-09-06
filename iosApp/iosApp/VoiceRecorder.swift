import Foundation
import AVFoundation

// Records a single spoken question to an m4a file, polling the input level while it runs so
// the mascot can visibly "listen" (Android does the same with MediaRecorder.maxAmplitude on
// a 60ms loop - see ChatViewModel.startRecording).
@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var amplitude: Double = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private(set) var fileURL: URL?

    /// Throws if the mic can't be started; caller shows the error.
    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.isMeteringEnabled = true
        guard rec.record() else { throw RecorderError.couldNotStart }

        recorder = rec
        fileURL = url
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            Task { @MainActor [weak self] in self?.sampleLevel() }
        }
    }

    /// Stops recording and returns the file if it captured anything usable.
    func stop() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil
        amplitude = 0
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let url = fileURL,
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return nil }
        return url
    }

    private func sampleLevel() {
        guard let recorder else { return }
        recorder.updateMeters()
        amplitude = AudioLevel.normalized(fromPower: recorder.averagePower(forChannel: 0))
    }

    enum RecorderError: LocalizedError {
        case couldNotStart
        var errorDescription: String? { "Couldn't start recording" }
    }
}
