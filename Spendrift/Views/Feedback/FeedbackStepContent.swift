//
//  FeedbackStepContent.swift
//  Spendrift
//

import SwiftUI
import UIKit

struct FeedbackStepContent: View {
    @Bindable var flow: FeedbackFlow
    @Binding var showLibrary: Bool

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var notesFocused: Bool

    private var accent: Color { AppTheme.accent }
    private var isDark: Bool { colorScheme == .dark }
    private var heroPrimary: Color { SettingsChrome.heroPrimary(isDark: isDark) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(flow.currentStep.question)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(heroPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                stepBody
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 44)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var stepBody: some View {
        switch flow.currentStep {
        case .uiApproval, .captureAccuracy, .aiFeatureRating, .recommend:
            FeedbackStarInput(
                selection: starBinding(for: flow.currentStep),
                accent: accent,
                heroPrimary: heroPrimary
            )
        case .foundWhere:
            singleChoiceList(FeedbackOptions.FoundWhere.allCases.map { ($0.id, $0.label) })
        case .shortcutsExplore:
            singleChoiceList(FeedbackOptions.ShortcutsExplore.allCases.map { ($0.id, $0.label) })
        case .whichShortcuts:
            multiChoiceList(
                FeedbackOptions.WhichShortcut.allCases.map { ($0.id, $0.label) },
                exclusive: FeedbackOptions.WhichShortcut.noneOfThese.rawValue
            )
        case .howTheyLog:
            multiChoiceList(
                FeedbackOptions.HowTheyLog.allCases.map { ($0.id, $0.label) },
                exclusive: FeedbackOptions.HowTheyLog.haventLogged.rawValue
            )
        case .whatWasWrong:
            singleChoiceList(FeedbackOptions.WhatWasWrong.allCases.map { ($0.id, $0.label) })
        case .aiFeatures:
            multiChoiceList(
                FeedbackOptions.AIFeature.allCases.map { ($0.id, $0.label) },
                exclusive: FeedbackOptions.AIFeature.noneOfThese.rawValue
            )
        case .proFeeling:
            singleChoiceList(FeedbackOptions.ProFeeling.allCases.map { ($0.id, $0.label) })
        case .notes:
            notesStep
        }
    }

    private var notesStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextEditor(text: $flow.draft.notes)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(heroPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .focused($notesFocused)
                .tint(heroPrimary)
                .overlay(alignment: .topLeading) {
                    if flow.draft.notes.isEmpty {
                        Text(flow.notesPlaceholder)
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.bottom, 8)

            feedbackMetaRow(title: "Screenshot", showsBottomDivider: flow.draft.screenshotData != nil) {
                Button {
                    notesFocused = false
                    showLibrary = true
                } label: {
                    HStack(spacing: 6) {
                        Text(flow.draft.screenshotData == nil ? "Attach" : "Attached")
                            .foregroundStyle(heroPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(heroPrimary.opacity(0.28))
                    }
                }
                .buttonStyle(.plain)
            }

            if let imageData = flow.draft.screenshotData,
               let uiImage = UIImage(data: imageData) {
                VStack(spacing: 12) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        flow.draft.screenshotData = nil
                    } label: {
                        Text("Remove screenshot")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(hex: "#FF6B6B"))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            }
        }
    }

    private func starBinding(for step: FeedbackStep) -> Binding<Int?> {
        Binding(
            get: { flow.draft.stars(for: step) },
            set: { value in
                if let value {
                    flow.setStars(value, for: step)
                }
            }
        )
    }

    private func singleChoiceList(_ options: [(id: String, label: String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                let isSelected = flow.draft.single(for: flow.currentStep) == option.id
                Button {
                    flow.setSingle(option.id, for: flow.currentStep)
                } label: {
                    FeedbackChoiceRow(
                        title: option.label,
                        isSelected: isSelected,
                        showsCheckmark: true,
                        accent: accent
                    )
                    .listItemPositioned(index: index, count: options.count)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func multiChoiceList(_ options: [(id: String, label: String)], exclusive: String) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                let isSelected = flow.draft.multi(for: flow.currentStep).contains(option.id)
                Button {
                    flow.toggleMulti(option.id, for: flow.currentStep, exclusive: exclusive)
                } label: {
                    FeedbackChoiceRow(
                        title: option.label,
                        isSelected: isSelected,
                        showsCheckmark: true,
                        accent: accent
                    )
                    .listItemPositioned(index: index, count: options.count)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func feedbackMetaRow<Trailing: View>(
        title: String,
        showsBottomDivider: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            trailing()
                .font(.system(size: 14, weight: .regular))
        }
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) {
            if showsBottomDivider {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Star input

struct FeedbackStarInput: View {
    @Binding var selection: Int?
    let accent: Color
    let heroPrimary: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(1 ... 5, id: \.self) { star in
                    Button {
                        selection = star
                    } label: {
                        Image(systemName: (selection ?? -1) >= star ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle((selection ?? -1) >= star ? accent : heroPrimary.opacity(0.28))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star")
                }
            }

            Button {
                selection = 0
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selection == 0 ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection == 0 ? accent : heroPrimary.opacity(0.28))
                    Text("0 - haven't used this / doesn't work for me")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(heroPrimary)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Choice row

struct FeedbackChoiceRow: View {
    let title: String
    let isSelected: Bool
    let showsCheckmark: Bool
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if showsCheckmark {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? accent : Color.primary.opacity(0.28))
            }

            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}
