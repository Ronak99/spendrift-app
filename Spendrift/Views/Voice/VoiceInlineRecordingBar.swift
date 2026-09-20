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
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
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

                    VoiceInlineLevelWaveform(meter: controller.levelMeter)
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

    private func errorContent(reason: VoiceFailureReason) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: errorIcon(for: reason))
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(reason.guidance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                primaryButton(for: reason)

                Button("Enter manually") {
                    controller.openManualFromError(accounts: accounts, hint: reason.guidance)
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                Button("Dismiss") {
                    controller.dismissError()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    /// Prominent, reason-aware recovery action: one-tap retry, or a deep link to Settings
    /// when microphone access has been denied.
    @ViewBuilder
    private func primaryButton(for reason: VoiceFailureReason) -> some View {
        Button {
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
        } label: {
            Label(reason.primaryActionTitle, systemImage: primaryActionIcon(for: reason.primaryAction))
        }
        .buttonStyle(.borderedProminent)
    }

    private func primaryActionIcon(for action: VoiceFailurePrimaryAction) -> String {
        switch action {
        case .retry:        return "arrow.clockwise"
        case .openSettings: return "gear"
        }
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
                tapSkipsToEnd: false,
                writeTaskPriority: .background
            )
            .padding(.horizontal, 4)
        }
    }
}

/// Voice Memos style waveform: each bar is one loudness sample mirrored around the centre
/// line, the newest sample enters at the right edge and history scrolls off to the left.
private struct VoiceInlineLevelWaveform: View {
    let meter: VoiceInputLevelMeter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barWidth: CGFloat = 2.5
    private let barSpacing: CGFloat = 3.5
    /// Silence draws as a dot as tall as it is wide, so the strip reads as "listening" and
    /// any speech visibly grows out of it.
    private var minBarHeight: CGFloat { barWidth }
    private let barColor = Color.red.opacity(0.8)

    var body: some View {
        // Samples arrive at 20 Hz; the strip is redrawn every frame so bars glide between
        // samples instead of jumping. Reading the meter here, not inside the Canvas renderer,
        // keeps the observation tracking that re-renders when a new sample lands.
        let samples = meter.samples
        let lastSampleAt = meter.lastSampleAt

        // With Reduce Motion the strip only redraws when a sample lands; the levels stay,
        // since they are information rather than decoration, but the glide is dropped.
        let redrawInterval: Double? = reduceMotion ? VoiceInputLevelMeter.sampleInterval : nil

        TimelineView(.animation(minimumInterval: redrawInterval, paused: !meter.isRunning)) { timeline in
            Canvas { context, size in
                let midY = size.height / 2
                let pitch = barWidth + barSpacing

                let baseline = CGRect(x: 0, y: midY - 0.5, width: size.width, height: 1)
                context.fill(Path(baseline), with: .color(barColor.opacity(0.25)))

                // Fraction of the sample interval already elapsed; shifts every bar left by
                // that much so the next sample can enter flush at the right edge.
                var glide: CGFloat = 0
                if !reduceMotion, let lastSampleAt {
                    let elapsed = timeline.date.timeIntervalSince(lastSampleAt)
                    glide = CGFloat(min(max(elapsed / VoiceInputLevelMeter.sampleInterval, 0), 1))
                }

                for (age, level) in samples.reversed().enumerated() {
                    let x = size.width - barWidth - (CGFloat(age) + glide) * pitch
                    guard x + barWidth > 0 else { break }
                    let height = max(minBarHeight, CGFloat(level) * size.height)
                    let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                    context.fill(Capsule().path(in: rect), with: .color(barColor))
                }
            }
        }
        .accessibilityHidden(true)
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
