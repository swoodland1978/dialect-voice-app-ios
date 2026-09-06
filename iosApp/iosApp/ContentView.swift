import SwiftUI
import Shared

// The chat screen, ported from the Android app's ChatScreen. Voice-first layout: the mascot
// is the centre of the screen with the waveform under it, dialect picker below that, text
// input at the bottom. Phase 1 has no mic button / audio playback yet (see ChatViewModel).
struct ContentView: View {
    @EnvironmentObject var auth: AuthController
    @StateObject private var viewModel: ChatViewModel

    init(auth: AuthController) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(auth: auth))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.background, Palette.surfaceVariant.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                LastQuestionView(text: viewModel.lastQuestion)

                AnimatedMascot(
                    isSpeaking: viewModel.isSpeaking,
                    isRecording: viewModel.recordingState == .recording,
                    isBusy: viewModel.isThinking,
                    hasError: viewModel.lastError != nil,
                    playbackAmplitude: viewModel.playbackAmplitude,
                    recordingAmplitude: viewModel.recordingAmplitude,
                    onTap: viewModel.mascotTapped
                )
                .frame(maxHeight: .infinity)

                AudioWaveform(
                    isSpeaking: viewModel.isSpeaking,
                    isRecording: viewModel.recordingState == .recording,
                    isBusy: viewModel.isThinking,
                    playbackAmplitude: viewModel.playbackAmplitude,
                    recordingAmplitude: viewModel.recordingAmplitude
                )
                .padding(.horizontal, 32)

                Spacer().frame(height: 6)

                DialectDropdown(
                    dialects: viewModel.dialects,
                    selection: $viewModel.selectedDialect
                )

                Spacer().frame(height: 6)

                ThinkingIndicator(isThinking: viewModel.isThinking)

                Spacer().frame(height: 4)

                inputRow
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Buy credit") { }   // phase 3 (paywall) - present for layout parity
                .font(.callout)
                .foregroundColor(Palette.primary)
            Spacer()
            Button {
                auth.signOut()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(Palette.onBackground)
            }
            .accessibilityLabel("Sign out")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message WhyAI…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Palette.surfaceVariant, in: RoundedRectangle(cornerRadius: 24))
                .onSubmit(viewModel.send)

            micButton

            Button {
                viewModel.send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(canSend ? Palette.onPrimary : Palette.onSurfaceVariant)
                    .frame(width: 48, height: 48)
                    .background(canSend ? Palette.primary : Palette.surfaceVariant, in: Circle())
            }
            .disabled(!canSend)
        }
        .padding(12)
    }

    @ViewBuilder
    private var micButton: some View {
        let recording = viewModel.recordingState == .recording
        let transcribing = viewModel.recordingState == .transcribing
        Button {
            recording ? viewModel.stopRecording() : viewModel.startRecording()
        } label: {
            ZStack {
                if transcribing {
                    ProgressView().tint(Palette.onSurfaceVariant)
                } else {
                    Image(systemName: recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(recording ? Palette.onPrimary : Palette.onSurfaceVariant)
                }
            }
            .frame(width: 48, height: 48)
            .background(recording ? Palette.recording : Palette.surfaceVariant, in: Circle())
        }
        .disabled(transcribing)
        .accessibilityLabel(recording ? "Stop recording" : "Record voice message")
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isLoading
    }
}

// The one bit of transcript the voice-only design keeps: only the most recent question,
// capped so a long one doesn't crowd the mascot.
private struct LastQuestionView: View {
    let text: String?

    var body: some View {
        if let text, !text.isEmpty {
            (Text("You: ").bold().foregroundColor(Palette.primary) + Text(text))
                .font(.body)
                .foregroundColor(Palette.onBackground)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
        }
    }
}

// Text dropdown for picking a dialect, ported from Android's DialectDropdown (label + short
// description per row).
private struct DialectDropdown: View {
    let dialects: [Dialect]
    @Binding var selection: Dialect?

    var body: some View {
        Menu {
            ForEach(dialects, id: \.id) { dialect in
                Button {
                    selection = dialect
                } label: {
                    Text(dialect.label)
                    Text(dialect.description_)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection?.label ?? "Select")
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundColor(Palette.onSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Palette.surfaceVariant, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
