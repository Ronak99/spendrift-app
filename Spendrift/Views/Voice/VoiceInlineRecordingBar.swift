//
//  VoiceInlineRecordingBar.swift
//  Spendrift
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
        VStack(spacing: 8) {
            if controller.displayState == .recording {
                VoiceCaptureExampleHintView()
                    .transition(.opacity)
            }

            barContent
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerSize: .init(width: 24, height: 24)))
                .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .animation(.bouncy, value: controller.displayState)
    }

    @ViewBuilder
    private var barContent: some View {
        switch controller.displayState {
        case .hidden:
            EmptyView()
        case .recording:
            recordingContent
        case .processing:
            processingContent
        case .error(let reason):
            errorContent(reason: reason)
        }
    }

    private var recordingContent: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: controller.displayState != .recording)) { timeline in
            let elapsed: Double = controller.recordingStartedAt.map {
                timeline.date.timeIntervalSince($0)
            } ?? 0
            let maxDuration = VoiceAudioPolicy.maxClipDurationSeconds
            let progress = min(elapsed / maxDuration, 1.0)

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

                    VoiceLevelWaveform(meter: controller.levelMeter)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)

                    ZStack {
                        Circle()
                            .trim(from: 0, to: max(0, 1 - progress))
                            .stroke(Color.red.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 40, height: 40)

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

                // Text(controller.recordingStartedAt == nil
                //      ? "Max \(VoiceAudioPolicy.maxClipDurationDisplayText)s per recording"
                //      : (secondsLeft > 0 ? "\(secondsLeft)s left" : "Submitting…"))
                //     .font(.caption)
                //     .foregroundStyle(.secondary)
                //     .contentTransition(.numericText(countsDown: true))
                //     .animation(.linear(duration: 0.2), value: secondsLeft)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .task(id: controller.recordingStartedAt) {
            guard let startedAt = controller.recordingStartedAt else { return }
            let remaining = VoiceAudioPolicy.maxClipDurationSeconds - Date().timeIntervalSince(startedAt)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled, controller.displayState == .recording else { return }
            controller.stopAndSubmit(
                modelContext: modelContext,
                accounts: accounts,
                categories: categories
            )
        }
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

    /// Failure card, 2A: one shell for every reason, separated only by the icon chip's
    /// tone. Amber marks what the app cannot fix by itself; everything recoverable takes
    /// the neutral chip. Exactly one filled action per card, with the escape hatch beside it.
    private func errorContent(reason: VoiceFailureReason) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                errorIconChip(for: reason)

                VStack(alignment: .leading, spacing: 6) {
                    Text(reason.title)
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(-0.17)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(reason.guidance)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VoiceErrorDismissButton {
                    controller.dismissError()
                }
                .id(reason)
                .padding(.top, -4)
                .padding(.trailing, -4)
            }

            HStack(spacing: 10) {
                Button(reason.primaryActionTitle) {
                    switch reason.primaryAction {
                    case .retry:
                        controller.retry(
                            modelContext: modelContext,
                            accounts: accounts,
                            categories: categories
                        )
                    case .openSettings:
                        controller.openSettings()
                    }
                }
                .buttonStyle(VoiceFailurePrimaryButtonStyle())

                Button(reason.secondaryActionTitle) {
                    controller.openManualFromError(accounts: accounts, hint: reason.guidance)
                }
                .buttonStyle(VoiceFailureSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    private func errorIconChip(for reason: VoiceFailureReason) -> some View {
        let tint: Color = reason.tone == .blocked ? .orange : .secondary

        return Image(systemName: errorIcon(for: reason))
            .font(.system(size: 18, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(reason.tone == .blocked ? 0.16 : 0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    private func errorIcon(for reason: VoiceFailureReason) -> String {
        switch reason {
        case .micPermissionDenied: return "mic.slash.fill"
        case .micUnavailable:      return "mic.slash"
        case .recordingTooShort:   return "clock"
        case .noSpeechDetected:    return "waveform.slash"
        case .audioUnreadable:     return "exclamationmark.triangle"
        case .transcriptionFailed: return "exclamationmark.bubble"
        case .unknown:             return "exclamationmark.triangle"
        }
    }
}

// MARK: - Failure card buttons

/// The single filled action on a failure card.
private struct VoiceFailurePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(hex: "#062E35"))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.75 : 1),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// The escape hatch beside it: same size, no fill.
private struct VoiceFailureSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.primary.opacity(configuration.isPressed ? 0.08 : 0),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
            )
    }
}

// MARK: - Error dismiss

/// Close control for the voice failure card. A thin ring counts down for 5 seconds,
/// then the card dismisses on its own. Tapping the cross dismisses immediately.
private struct VoiceErrorDismissButton: View {
    private static let lifetime: TimeInterval = 5

    let onDismiss: () -> Void

    @State private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            let remaining = reduceMotion ? 1.0 : max(0, 1 - elapsed / Self.lifetime)
            closeButton(ringFraction: remaining)
        }
        .task {
            try? await Task.sleep(for: .seconds(Self.lifetime))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    private func closeButton(ringFraction: Double) -> some View {
        Button(action: onDismiss) {
            ZStack {
                Circle()
                    .trim(from: 0, to: ringFraction)
                    .stroke(
                        Color.primary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(0.5)
                    .transaction { $0.animation = nil }

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
    }
}

// MARK: - Recording hints

/// One random example phrase per recording session; streams in once and stays until recording ends.
private struct VoiceCaptureExampleHintView: View {
    private let script: String?

    init() {
        script = VoiceCaptureHints.randomScript()
    }

    var body: some View {
        if let script {
            StreamingText(
                text: script,
                cadence: .fast,
                font: .system(size: 12, weight: .regular),
                textColor: Color.secondary.opacity(0.72),
                multilineTextAlignment: .leading,
                contentAlignment: .leading,
                writeTaskPriority: .background
            )
            .padding(.horizontal, 4)
        }
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
        TransactionCategory(name: "Transport", type: .expense),
        TransactionCategory(name: "Salary", type: .income)
    ]

    /// Failure reasons to iterate on error copy in the canvas.
    static let sampleReasons: [VoiceFailureReason] = [
        .micPermissionDenied,
        .recordingTooShort,
        .noSpeechDetected,
        .transcriptionFailed
    ]
}

/// Hosts the bar over a neutral background; change `state` to switch canvas variants.
private struct VoiceInlineRecordingBarPreviewHost: View {
    var state: VoiceInlineDisplayState
    @State private var controller = VoiceInlineCaptureController()

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.listBackground
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

#Preview("Error — recording too short") {
    VoiceInlineRecordingBarPreviewHost(state: .error(.recordingTooShort))
}

#Preview("Error — mic permission") {
    VoiceInlineRecordingBarPreviewHost(state: .error(.micPermissionDenied))
}

#Preview("Error — transcription failed") {
    VoiceInlineRecordingBarPreviewHost(state: .error(.transcriptionFailed))
}

#Preview("Gallery — failure reasons") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .bottom, spacing: 16) {
            previewCell(title: "Recording", state: .recording)
            previewCell(title: "Processing", state: .processing)
            ForEach(VoiceInlineRecordingBarPreviewData.sampleReasons, id: \.self) { reason in
                previewCell(title: reason.analyticsValue, state: .error(reason))
            }
        }
        .padding()
    }
    .background(AppTheme.listBackground)
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
