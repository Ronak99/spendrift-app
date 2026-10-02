//
//  OnboardingFlowView.swift
//  Spendrift
//
//  First run, full screen, three pages.
//
//  The flow is a demo rather than a tour: the middle page records the user's actual
//  voice, sends it to the actual parser, and writes the transaction to the ledger
//  stamped with now. By the time they reach the end they have already used the
//  feature the app is built on, and Home already has a row to show.
//

import SwiftData
import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    @Binding var onboardingVersion: Int
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @State private var step: OnboardingStep = .welcome
    @State private var voice = OnboardingVoiceDemoController()

    var body: some View {
        ZStack {
            OnboardingSheetAtmosphericBackground(tintColor: step.accent)
                .ignoresSafeArea()

            OnboardingCornerWatermark(mark: step.watermark)
                .washMotion(value: step)

            page
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Analytics.capture(.onboardingStepViewed, [Analytics.Key.step: step.analyticsName])
        }
        .onChange(of: step) { previous, current in
            if previous == .voice { voice.cancel() }
            Analytics.capture(.onboardingStepViewed, [Analytics.Key.step: current.analyticsName])
        }
    }

    /// The transition sits on each branch rather than on the `switch` as a whole: SwiftUI
    /// resolves it from the subtree that is actually inserted and removed.
    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome:
            OnboardingWelcomePage(onContinue: advance)
                .transition(pageTransition)
        case .voice:
            OnboardingVoicePage(
                voice: voice,
                accounts: accounts,
                categories: categories,
                onContinue: advance
            )
            .transition(pageTransition)
        case .pro:
            OnboardingProPage(onFinish: advance)
                .transition(pageTransition)
        }
    }

    /// Pages arrive from the right and leave to the left, so moving forward reads as one
    /// continuous strip rather than a stack of modals.
    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var pageAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.92)
    }

    private func advance() {
        guard let next = step.next else {
            complete()
            return
        }
        withAnimation(pageAnimation) { step = next }
    }

    private func complete() {
        voice.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Analytics.capture(.onboardingCompleted, [Analytics.Key.version: Self.currentVersion])
        onboardingVersion = Self.currentVersion
        AudienceTags.scheduleSync()
        onFinished?()
    }

    /// Kill switch for the first-run walkthrough.
    static let isEnabled = true

    /// When true, every cold launch presents onboarding. Fin. dismisses it for the rest
    /// of this session. Turn off before shipping so versioned first-run is the only gate.
    static let showsEveryLaunch = true

    /// Bump to re-show onboarding on major updates.
    static let currentVersion = 3
}

// MARK: - Page 1: Welcome

private struct OnboardingWelcomePage: View {
    let onContinue: () -> Void

    private let accent = OnboardingStep.welcome.accent

    /// The same features the Pro paywall leads with, so the offer later on is something
    /// they have already been told about.
    private static let features: [ProFeature] = [.voice, .messageImport]

    var body: some View {
        OnboardingPage {
            // The paywall's hero section: glass mark, name, one line under it.
            VStack(spacing: 20) {
                GlassHeroMark(assetName: OnboardingVisualAsset.proHeroMark, accent: accent)

                VStack(spacing: 10) {
                    Text("Spendrift")
                        .font(.title2.bold())
                        .foregroundStyle(OnboardingTheme.textPrimary)

                    Text("Simplifying personal finance.")
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        } focus: {
            ProFeatureCard(features: Self.features, accent: accent)
        } action: {
            OnboardingActionButton(
                title: "Show me how",
                fill: accent,
                action: onContinue
            )
        }
    }
}

// MARK: - Page 2: Voice

private struct OnboardingVoicePage: View {
    let voice: OnboardingVoiceDemoController
    let accounts: [Account]
    let categories: [TransactionCategory]
    let onContinue: () -> Void

    @Environment(\.modelContext) private var modelContext
    /// Picked fresh on every tap of the mic, so a second attempt offers a new idea.
    @State private var exampleScript: String?

    private let accent = OnboardingStep.voice.accent

    private var hasHeard: Bool {
        if case .heard = voice.phase { return true }
        return false
    }

    var body: some View {
        OnboardingPage {
            OnboardingNarration(
                headline: "Just say it.",
                detail: "One tap, one sentence. Done."
            )
        } focus: {
            focus
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: voice.phase)
        } action: {
            // The demo is an offer, not a gate, so the way past it is there from the
            // first frame. Quiet until they have heard it work, so it does not compete
            // with the plate, which is still the thing to tap. One button throughout, so
            // it morphs into the filled capsule rather than being swapped for one.
            OnboardingActionButton(
                title: hasHeard ? "Awesome, next" : "I'll do it later",
                fill: accent,
                style: hasHeard ? .filled : .quiet,
                action: onContinue
            )
            // A clip already being read will still land in the ledger, so the page
            // holds for the moment it takes to show them the result.
            .disabled(voice.phase == .thinking)
            .opacity(voice.phase == .thinking ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.2), value: voice.phase == .thinking)
        }
        // Stopping the clip is the user's job, but a clip that runs to the cap submits
        // itself rather than being thrown away.
        .task(id: voice.startedAt) {
            guard let startedAt = voice.startedAt else { return }
            let remaining = VoiceAudioPolicy.maxClipDurationSeconds - Date().timeIntervalSince(startedAt)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled, voice.isListening else { return }
            voice.stopAndParse(
                modelContext: modelContext,
                accounts: accounts,
                categories: categories
            )
        }
    }

    @ViewBuilder
    private var focus: some View {
        if case .heard(let heard) = voice.phase {
            VStack(spacing: 16) {
                OnboardingHeardTransactionCard(heard: heard)

                OnboardingTapHint(text: tapHint)
            }
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        } else {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    OnboardingHeroPlate(
                        mark: .symbol(voice.isListening ? "stop.fill" : "mic.fill"),
                        accent: accent,
                        levelMeter: voice.isListening ? voice.levelMeter : nil,
                        isBusy: voice.phase == .thinking,
                        accessibilityLabel: voice.isListening
                            ? "Stop and read it back"
                            : "Speak an expense",
                        action: handleTap
                    )

                    OnboardingTapHint(text: tapHint)
                }

                VoiceLevelWaveform(meter: voice.levelMeter, tint: accent.opacity(0.85))
                    .frame(width: 200, height: 26)
                    .opacity(voice.isListening ? 1 : 0)
            }
            .transition(.opacity)
        }
    }

    /// An invitation first time round, what is happening while they speak, the payoff
    /// under the heard card, and an offer of a second go after a run that did not work
    /// out - no blame and no diagnosis, the button below is always the other way forward.
    private var tapHint: String? {
        switch voice.phase {
        case .idle:      "Tap me"
        // An example gives them something to say the moment the mic opens.
        case .listening: exampleScript.map { "Try saying \"\($0)\"" }
            ?? "Your language, your dialect. Say what you spent."
        case .thinking:  nil
        case .heard:     "Voila! An app that works for you."
        case .failed:    "Give it another shot?"
        }
    }

    private func handleTap() {
        switch voice.phase {
        case .idle, .failed:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            exampleScript = VoiceCaptureHints.randomScript()
            Task { await voice.beginListening() }
        case .listening:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            voice.stopAndParse(
                modelContext: modelContext,
                accounts: accounts,
                categories: categories
            )
        case .thinking, .heard:
            break
        }
    }
}

// MARK: - Page 3: Pro

private struct OnboardingProPage: View {
    let onFinish: () -> Void

    @AppStorage(NotificationManager.Keys.dailyReminderEnabled) private var dailyReminderEnabled = true
    @AppStorage(NotificationManager.Keys.dailyReminderHour) private var dailyReminderHour = NotificationManager.defaultHour
    @AppStorage(NotificationManager.Keys.dailyReminderMinute) private var dailyReminderMinute = NotificationManager.defaultMinute

    @State private var reward: RewardState = .offered
    /// "I'll do it later" holds back so "Notify Me." gets a moment to be read first.
    @State private var showsLater = false

    private enum RewardState {
        case offered
        case asking
        case granted
        /// Asked and refused, or already refused at the system level.
        case declined
    }

    private let accent = OnboardingStep.pro.accent

    var body: some View {
        OnboardingPage {
            OnboardingNarration(
                headline: "Turn on notifications.",
                detail: "To receive 10 free voice notes."
            )
        } focus: {
            VStack(spacing: 16) {
                Image(OnboardingVisualAsset.notificationPreview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Example notification. Your free AI credits are back.")

                OnboardingTapHint(text: tapHint)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: reward)
        } action: {
            VStack(spacing: 4) {
                // One button throughout, so it morphs from the offer into the way out
                // once the offer has been answered.
                OnboardingActionButton(
                    title: hasAnswered ? "Let's go." : "Notify Me.",
                    fill: accent,
                    action: hasAnswered ? onFinish : requestNotifications
                )
                .disabled(reward == .asking)

                // Always laid out, so "Notify Me." sits where it will stay when this
                // fades in, and does not move when it fades out again.
                OnboardingActionButton(
                    title: "I'll do it later",
                    fill: accent,
                    style: .quiet,
                    action: onFinish
                )
                .opacity(showsLater && reward == .offered ? 1 : 0)
                .allowsHitTesting(showsLater && reward == .offered)
                .accessibilityHidden(!(showsLater && reward == .offered))
                .animation(.easeInOut(duration: 0.32), value: showsLater)
                .animation(.easeInOut(duration: 0.32), value: reward)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showsLater = true
        }
    }

    private var hasAnswered: Bool {
        reward == .granted || reward == .declined
    }

    private var tapHint: String? {
        switch reward {
        case .offered:  nil
        case .asking:   "One moment."
        case .granted:  "Done. Ten voice notes, five receipts and a statement, on us."
        // Free credits wait for next month unless they change their mind in Settings.
        case .declined: "No bother. Free credits start \(nextRefillText), or sooner from Settings."
        }
    }

    private var nextRefillText: String {
        AIQuotaStore.nextResetDate().formatted(.dateTime.day().month(.abbreviated))
    }

    private func requestNotifications() {
        reward = .asking
        Task { @MainActor in
            guard await PushNotifications.enableFromSettings() else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    reward = .declined
                }
                return
            }

            // The user has just said yes to being notified, so schedule the daily spend
            // reminders here rather than asking a second time after their first entry.
            dailyReminderEnabled = true
            NotificationManager.reschedule(
                enabled: true,
                hour: dailyReminderHour,
                minute: dailyReminderMinute
            )

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                reward = .granted
            }
        }
    }
}

#if DEBUG
#Preview("Flow") {
    OnboardingFlowView(onboardingVersion: .constant(0))
        .modelContainer(
            for: [Transaction.self, Account.self, TransactionCategory.self],
            inMemory: true
        )
}
#endif
