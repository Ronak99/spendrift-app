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
        .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        .padding(.horizontal, 0)
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
                    Text("Stop")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and save")
            }

            Text("Speak your transaction — we’ll save it automatically when you tap Stop.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.85))
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

