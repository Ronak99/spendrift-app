//
//  FeedbackStepContent.swift
//  Spendrift
//
//  Card, radio, and star controls for the single-page feedback survey.
//  Every structured question is a single choice so answering can scroll
//  the next question into place. Visual language matches
//  spendrift-future-works/feedback.
//

import SwiftUI

enum FeedbackSurveyChrome {
    static let cardRadius: CGFloat = 16
    /// Extra space between question blocks, on top of each section's scroll clearance.
    static let sectionGap: CGFloat = 8
    /// Top inset inside every question so `scrollTo` lands below the progress bar.
    static let scrollClearance: CGFloat = 32
    static let titleToCardGap: CGFloat = 14
    static let rowHorizontal: CGFloat = 16
    static let rowVertical: CGFloat = 15
    static let markSize: CGFloat = 21
    static let innerMarkSize: CGFloat = 11
    static let progressHeight: CGFloat = 2.5

    static func cardFill(isDark: Bool) -> Color {
        isDark ? Color(hex: "#15181B") : AppTheme.listGroupBackground
    }

    static func unselectedLabel(isDark: Bool) -> Color {
        isDark ? Color(hex: "#D7DCE0") : Color.primary.opacity(0.78)
    }

    static func prompt(isDark: Bool) -> Color {
        isDark ? Color(hex: "#7D858D") : Color.primary.opacity(0.45)
    }

    static var hairline: Color {
        Color.primary.opacity(0.06)
    }
}

struct FeedbackSurveyProgressBar: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 0,
                        bottomLeading: 0,
                        bottomTrailing: 2,
                        topTrailing: 2
                    ),
                    style: .continuous
                )
                .fill(accent)
                .frame(width: max(0, geo.size.width * progress))
            }
        }
        .frame(height: FeedbackSurveyChrome.progressHeight)
        .accessibilityLabel("Survey progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.35), value: progress)
    }
}

struct FeedbackQuestionHeader: View {
    let step: FeedbackStep
    let heroPrimary: Color
    let promptColor: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(step.question)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(heroPrimary)

                if let prompt = step.prompt {
                    Text(prompt)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(promptColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let accessory = step.accessoryLabel {
                Text(accessory)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(promptColor)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct FeedbackQuestionCard<Content: View>: View {
    let isDark: Bool
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: FeedbackSurveyChrome.cardRadius,
            style: .continuous
        )
        VStack(spacing: 0) {
            content
        }
        .background(FeedbackSurveyChrome.cardFill(isDark: isDark), in: shape)
        .overlay {
            shape.strokeBorder(FeedbackSurveyChrome.hairline, lineWidth: 1)
        }
        .clipShape(shape)
    }
}

struct FeedbackSelectionMark: View {
    let isSelected: Bool
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? accent : Color.primary.opacity(0.22),
                    lineWidth: 1.5
                )
            Circle()
                .fill(accent)
                .frame(
                    width: isSelected ? FeedbackSurveyChrome.innerMarkSize : 0,
                    height: isSelected ? FeedbackSurveyChrome.innerMarkSize : 0
                )
        }
        .frame(
            width: FeedbackSurveyChrome.markSize,
            height: FeedbackSurveyChrome.markSize
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityHidden(true)
    }
}

struct FeedbackChoiceRow: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    var isLast: Bool = false
    var unselectedLabel: Color = Color.primary.opacity(0.78)

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .tracking(-0.1)
                .foregroundStyle(isSelected ? Color.primary : unselectedLabel)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            FeedbackSelectionMark(isSelected: isSelected, accent: accent)
        }
        .padding(.horizontal, FeedbackSurveyChrome.rowHorizontal)
        .padding(.vertical, FeedbackSurveyChrome.rowVertical)
        .background(isSelected ? accent.opacity(0.07) : Color.clear)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(FeedbackSurveyChrome.hairline)
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FeedbackStarInput: View {
    @Binding var selection: Int?
    let accent: Color
    let heroPrimary: Color

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1 ... 5, id: \.self) { star in
                Button {
                    selection = selection == star ? nil : star
                } label: {
                    Image(systemName: filled(star) ? "star.fill" : "star")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(filled(star) ? accent : heroPrimary.opacity(0.28))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) star")
                .accessibilityAddTraits(selection == star ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
    }

    private func filled(_ star: Int) -> Bool {
        guard let value = selection else { return false }
        return value >= star
    }
}
