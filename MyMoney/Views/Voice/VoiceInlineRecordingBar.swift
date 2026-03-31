//
//  VoiceInlineRecordingBar.swift
//  MyMoney
//
//  Created by Cursor on 28/03/26.
//

import SwiftData
import SwiftUI

struct VoiceInlineRecordingBar: View {
    @Bindable var controller: VoiceInlineCaptureController
    @Environment(\.modelContext) private var modelContext
    let accounts: [Account]
    let categories: [TransactionCategory]

    var body: some View {
        VStack(spacing: 0) {
            switch controller.displayState {
            case .hidden:
                EmptyView()
            case .recording:
                recordingContent
            case .processing:
                processingContent
            case .error(let message):
                errorContent(message: message)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerSize: .init(width: 24, height: 24)))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .animation(.bouncy)
    }

    private var recordingContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    controller.cancelCapture()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel recording")

                VoiceInlineMiniWaveform(isActive: true)
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)

                Button {
                    controller.stopAndSubmit(
                        modelContext: modelContext,
                        accounts: accounts,
                        categories: categories
                    )
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and save")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var processingContent: some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Saving…")
                    .font(.subheadline.weight(.medium))
                Text("You can still scroll and use the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }

    private func errorContent(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Dismiss") {
                    controller.dismissError()
                }
                .buttonStyle(.bordered)

                Button("Enter manually") {
                    controller.openManualFromError(accounts: accounts, hint: message)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

private struct VoiceInlineMiniWaveform: View {
    var isActive: Bool
    private let barCount = 28

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06, paused: !isActive)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 7) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(.red.opacity(0.8))
                        .frame(width: 2.5, height: barHeight(index: index, t: t))
                }
            }
        }
    }

    private func barHeight(index: Int, t: TimeInterval) -> CGFloat {
        let phase = t * 14
        let wave = sin(Double(index) * 0.45 + phase) * 0.5 + sin(Double(index) * 0.15 + phase * 0.8) * 0.35
        let normalized = (wave + 1) / 2
        return CGFloat(normalized) * 22 + 4
    }
}

// MARK: - Previews

#if DEBUG
private enum VoiceInlineRecordingBarPreviewData {
    static let accounts: [Account] = [
        Account(name: "HDFC Primary", balance: 42_500, icon: .bankAccountFour, isPrimary: true),
        Account(name: "Cash", balance: 1_200, icon: .unknown, isPrimary: false)
    ]

    static let categories: [TransactionCategory] = [
        TransactionCategory(name: "Food", type: .expense),
        TransactionCategory(name: "Transportation", type: .expense),
        TransactionCategory(name: "Salary", type: .income)
    ]

    /// Tweak this string to iterate on error copy in the canvas.
    static let sampleErrorMessage = "Transaction could not be created."
}

/// Hosts the bar over a neutral background; change `state` to switch canvas variants.
private struct VoiceInlineRecordingBarPreviewHost: View {
    var state: VoiceInlineDisplayState
    @State private var controller = VoiceInlineCaptureController()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            VoiceInlineRecordingBar(
                controller: controller,
                accounts: VoiceInlineRecordingBarPreviewData.accounts,
                categories: VoiceInlineRecordingBarPreviewData.categories
            )
        }
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
        .onAppear {
            controller.applyPreviewDisplayState(state)
        }
    }
}

#Preview("Recording") {
    VoiceInlineRecordingBarPreviewHost(state: .recording)
}

#Preview("Processing") {
    VoiceInlineRecordingBarPreviewHost(state: .processing)
}

#Preview("Error") {
    VoiceInlineRecordingBarPreviewHost(state: .error(VoiceInlineRecordingBarPreviewData.sampleErrorMessage))
}

#Preview("Gallery — all states") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .bottom, spacing: 16) {
            previewCell(title: "Recording", state: .recording)
            previewCell(title: "Processing", state: .processing)
            previewCell(title: "Error", state: .error(VoiceInlineRecordingBarPreviewData.sampleErrorMessage))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

@MainActor
private func previewCell(title: String, state: VoiceInlineDisplayState) -> some View {
    VStack(spacing: 8) {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        VoiceInlineRecordingBarPreviewHost(state: state)
            .frame(width: 390)
    }
}
#endif
