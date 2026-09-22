//
//  FeedbackView.swift
//  Spendrift
//
//  Single-page in-app feedback survey. Submissions go to Supabase keyed by
//  DeviceIdentity.current. Questions can be left blank; submit sends whatever
//  the user filled in.
//
//  Layout and scroll-on-answer behavior match
//  spendrift-future-works/feedback/Feedback Screen.dc.html.
//

import SwiftUI
import UIKit

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var flow = FeedbackFlow()
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var showThanks = false
    @State private var errorMessage = ""
    @State private var scrollTask: Task<Void, Never>?
    @FocusState private var notesFocused: Bool

    private var accent: Color { AppTheme.accent }
    private var isDark: Bool { colorScheme == .dark }
    private var heroPrimary: Color { SettingsChrome.heroPrimary(isDark: isDark) }
    private var promptColor: Color { FeedbackSurveyChrome.prompt(isDark: isDark) }
    private var unselectedLabel: Color { FeedbackSurveyChrome.unselectedLabel(isDark: isDark) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: FeedbackSurveyChrome.sectionGap) {
                    ForEach(flow.visibleSteps) { step in
                        section(for: step)
                            .padding(.top, FeedbackSurveyChrome.scrollClearance)
                            .id(step)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .softScrollEdge()
            .onChange(of: flow.scrollPulse) { _, pulse in
                guard let pulse else { return }
                scrollToNextQuestion(pulse.step, proxy: proxy)
            }
        }
        .background {
            SettingsAtmosphere(washColor: AppTheme.atmosphere)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            FeedbackSurveyProgressBar(progress: flow.surveyProgress, accent: accent)
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .tint(AppTheme.atmosphere)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: flow.visibleSteps)
        .sensoryFeedback(.selection, trigger: flow.scrollPulse)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .confirmationAction) {
                    submitButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    submitButton
                }
            }
        }
        .onDisappear {
            scrollTask?.cancel()
        }
        .alert("Couldn't send feedback", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Thanks for your feedback", isPresented: $showThanks) {
            Button("Done") { dismiss() }
        } message: {
            Text("We read every submission.")
        }
    }

    @ViewBuilder
    private func section(for step: FeedbackStep) -> some View {
        switch step {
        case .uiApproval:
            starSection(for: .uiApproval)
        case .foundWhere:
            choiceSection(
                for: .foundWhere,
                options: FeedbackOptions.FoundWhere.allCases.map { ($0.id, $0.label) }
            )
        case .shortcutsExplore:
            choiceSection(
                for: .shortcutsExplore,
                options: FeedbackOptions.ShortcutsExplore.allCases.map { ($0.id, $0.label) }
            )
        case .howTheyLog:
            choiceSection(
                for: .howTheyLog,
                options: FeedbackOptions.HowTheyLog.allCases.map { ($0.id, $0.label) }
            )
        case .captureAccuracy:
            starSection(for: .captureAccuracy)
        case .whatWasWrong:
            choiceSection(
                for: .whatWasWrong,
                options: FeedbackOptions.WhatWasWrong.allCases.map { ($0.id, $0.label) }
            )
        case .aiFeatures:
            choiceSection(
                for: .aiFeatures,
                options: FeedbackOptions.AIFeature.allCases.map { ($0.id, $0.label) }
            )
        case .aiFeatureRating:
            starSection(for: .aiFeatureRating)
        case .proFeeling:
            choiceSection(
                for: .proFeeling,
                options: FeedbackOptions.ProFeeling.allCases.map { ($0.id, $0.label) }
            )
        case .notes:
            notesSection
        }
    }

    @ViewBuilder
    private func starSection(for step: FeedbackStep) -> some View {
        VStack(alignment: .leading, spacing: FeedbackSurveyChrome.titleToCardGap) {
            FeedbackQuestionHeader(
                step: step,
                heroPrimary: heroPrimary,
                promptColor: promptColor
            )

            FeedbackQuestionCard(isDark: isDark) {
                FeedbackStarInput(
                    selection: starBinding(for: step),
                    accent: accent,
                    heroPrimary: heroPrimary
                )
            }
        }
    }

    @ViewBuilder
    private func choiceSection(
        for step: FeedbackStep,
        options: [(id: String, label: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: FeedbackSurveyChrome.titleToCardGap) {
            FeedbackQuestionHeader(
                step: step,
                heroPrimary: heroPrimary,
                promptColor: promptColor
            )

            FeedbackQuestionCard(isDark: isDark) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    let isSelected = flow.draft.single(for: step) == option.id
                    Button {
                        flow.setSingle(option.id, for: step)
                    } label: {
                        FeedbackChoiceRow(
                            title: option.label,
                            isSelected: isSelected,
                            accent: accent,
                            isLast: index == options.count - 1,
                            unselectedLabel: unselectedLabel
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: FeedbackSurveyChrome.titleToCardGap) {
            FeedbackQuestionHeader(
                step: .notes,
                heroPrimary: heroPrimary,
                promptColor: promptColor
            )

            FeedbackQuestionCard(isDark: isDark) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: notesBinding)
                        .font(.system(size: 14.5, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(heroPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 88)
                        .focused($notesFocused)
                        .tint(accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                    if flow.draft.notes.isEmpty {
                        Text(flow.notesPlaceholder)
                            .font(.system(size: 14.5))
                            .foregroundStyle(promptColor)
                            .padding(.top, 18)
                            .padding(.leading, 17)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { flow.draft.notes },
            set: { flow.draft.notes = $0 }
        )
    }

    private func starBinding(for step: FeedbackStep) -> Binding<Int?> {
        Binding(
            get: { flow.draft.stars(for: step) },
            set: { value in
                if let value {
                    flow.setStars(value, for: step)
                } else {
                    flow.clearAnswer(for: step)
                }
            }
        )
    }

    private var submitButton: some View {
        Button(action: submit) {
            SettingsCapsuleLabel(title: isSubmitting ? "Sending..." : "Submit")
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting || !flow.canSubmit)
        .opacity((isSubmitting || !flow.canSubmit) ? 0.4 : 1)
        .accessibilityLabel(isSubmitting ? "Sending feedback" : "Submit feedback")
    }

    private func scrollToNextQuestion(_ step: FeedbackStep, proxy: ScrollViewProxy) {
        scrollTask?.cancel()
        scrollTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)) {
                proxy.scrollTo(step, anchor: .top)
            }
        }
    }

    private func submit() {
        guard !isSubmitting, flow.canSubmit else { return }
        isSubmitting = true
        Task {
            do {
                let client = try FeedbackClient()
                try await client.submit(draft: flow.draft)
                Analytics.capture(.feedbackSubmitted, [
                    Analytics.Key.skippedToNotes: flow.draft.skippedToNotes
                ])
                await MainActor.run {
                    isSubmitting = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showThanks = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
