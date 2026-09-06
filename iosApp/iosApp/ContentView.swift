import SwiftUI
import Shared

// UNVERIFIED - see STATUS.md and ChatViewModel.swift's header. Plain SwiftUI (no Shared
// interop) below this file's own view logic is standard/well-established syntax; the risk
// is entirely in what ChatViewModel does when it talks to the Shared module.
struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Dialect", selection: $viewModel.selectedDialect) {
                ForEach(viewModel.dialects, id: \.id) { dialect in
                    Text(dialect.label).tag(Optional(dialect))
                }
            }
            .pickerStyle(.menu)
            .padding()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        MessageRow(message: message)
                    }
                }
                .padding()
            }

            if viewModel.isLoading {
                ProgressView("Thinking...")
                    .padding(.bottom, 8)
            }

            if let error = viewModel.lastError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.horizontal)
            }

            HStack {
                TextField("Ask something...", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { viewModel.send() }
                Button("Send") { viewModel.send() }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }
}

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .padding(10)
                .background(message.role == .user ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.15))
                .cornerRadius(10)
            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    ContentView()
}
