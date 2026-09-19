//
//  FeedbackFlow.swift
//  Spendrift
//
//  Single-page feedback survey state. Branching still follows
//  Spendrift/docs/FEEDBACK_FORM.md, but every structured question is a
//  single choice so answering can scroll the next question into place.
//

import Foundation

// MARK: - Steps

enum FeedbackStep: Equatable, Hashable, CaseIterable {
    case uiApproval
    case foundWhere
    case shortcutsExplore
    case howTheyLog
    case captureAccuracy
    case whatWasWrong
    case aiFeatures
    case aiFeatureRating
    case proFeeling
    case notes
}

// MARK: - Answer types

enum FeedbackAnswerValue: Equatable {
    case stars(Int)
    case single(String)
}

struct FeedbackAnswer: Equatable {
    let type: String
    let value: FeedbackAnswerValue

    func encode() -> [String: Any] {
        switch value {
        case .stars(let n):
            return ["type": type, "value": n]
        case .single(let id):
            return ["type": type, "value": id]
        }
    }
}

/// One-shot request to scroll the survey to the next question after an answer.
struct FeedbackScrollPulse: Equatable {
    let step: FeedbackStep
    let nonce: UInt64
}

// MARK: - Option catalogs

enum FeedbackOptions {
    enum FoundWhere: String, CaseIterable, Identifiable {
        case reddit, youtube, appStore = "app_store", linkedIn = "linked_in", other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .reddit: "Reddit"
            case .youtube: "YouTube"
            case .appStore: "App Store"
            case .linkedIn: "LinkedIn"
            case .other: "Other"
            }
        }
    }

    enum ShortcutsExplore: String, CaseIterable, Identifiable {
        case openedExploreOrOnboarding = "opened_explore_or_onboarding"
        case sawButDidntAdd = "saw_but_didnt_add"
        case addedAtLeastOne = "added_at_least_one"
        case didntKnow = "didnt_know"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .openedExploreOrOnboarding: "Yes, I opened the Explore option"
            case .sawButDidntAdd: "I saw them but didn't add any"
            case .addedAtLeastOne: "I added at least one shortcut"
            case .didntKnow: "I didn't know they existed"
            }
        }
    }

    enum HowTheyLog: String, CaseIterable, Identifiable {
        case typeInApp = "type_in_app"
        case speak
        case bankSms = "bank_sms"
        case haventLogged = "havent_logged"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .typeInApp: "I type most expenses in the app"
            case .speak: "I speak them, in the app or via shortcut"
            case .bankSms: "Bank SMS logs them for me"
            case .haventLogged: "I haven't logged one yet"
            }
        }
    }

    enum WhatWasWrong: String, CaseIterable, Identifiable {
        case wrongAmount = "wrong_amount"
        case wrongCategory = "wrong_category"
        case wrongAccount = "wrong_account"
        case failedReenter = "failed_reenter"
        case notSure = "not_sure"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .wrongAmount: "It got the amount wrong"
            case .wrongCategory: "It picked the wrong category"
            case .wrongAccount: "It put it on the wrong account"
            case .failedReenter: "It failed and I had to re-enter"
            case .notSure: "Not sure what went wrong"
            }
        }
    }

    enum AIFeature: String, CaseIterable, Identifiable {
        case voiceCapture = "voice_capture"
        case bankSmsImport = "bank_sms_import"
        case noneOfThese = "none_of_these"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .voiceCapture: "I've used voice capture"
            case .bankSmsImport: "I've imported bank SMS"
            case .noneOfThese: "I haven't tried any of these"
            }
        }
    }

    enum ProFeeling: String, CaseIterable, Identifiable {
        case worthPaying = "worth_paying"
        case freeEnough = "free_enough"
        case noSubscription = "no_subscription"
        case alreadySubscribe = "already_subscribe"
        case haventHitPaywall = "havent_hit_paywall"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .worthPaying: "The AI features feel worth paying for"
            case .freeEnough: "The free limits are enough for me"
            case .noSubscription: "I don't want a subscription"
            case .alreadySubscribe: "I have already subscribed"
            case .haventHitPaywall: "I haven't hit the paywall yet"
            }
        }
    }
}

extension FeedbackStep {
    var questionKey: String {
        switch self {
        case .uiApproval: "ui_approval"
        case .foundWhere: "found_where"
        case .shortcutsExplore: "shortcuts_explored"
        case .howTheyLog: "how_they_log"
        case .captureAccuracy: "capture_accuracy"
        case .whatWasWrong: "what_was_wrong"
        case .aiFeatures: "ai_features"
        case .aiFeatureRating: "ai_feature_rating"
        case .proFeeling: "pro_feeling"
        case .notes: "notes"
        }
    }

    var question: String {
        switch self {
        case .uiApproval: "How does the app look and feel?"
        case .foundWhere: "Where did you find Spendrift?"
        case .shortcutsExplore: "Have you looked at the shortcuts Spendrift offers?"
        case .howTheyLog: "What's the main way you log spending in Spendrift?"
        case .captureAccuracy: "When you log something, how often does Spendrift get it right?"
        case .whatWasWrong: "What was wrong most often?"
        case .aiFeatures: "Which AI feature have you actually used?"
        case .aiFeatureRating: "How was that feature?"
        case .proFeeling: "How do you feel about Pro?"
        case .notes: "Anything else you want to share?"
        }
    }

    var prompt: String? {
        switch self {
        default: nil
        }
    }

    var accessoryLabel: String? {
        switch self {
        default: nil
        }
    }

    /// Structured answers auto-advance so the next question scrolls into place.
    var advancesOnAnswer: Bool {
        self != .notes
    }
}

extension FeedbackStep: Identifiable {
    var id: Self { self }
}

// MARK: - Draft + flow

struct FeedbackDraft: Equatable {
    var answers: [FeedbackStep: FeedbackAnswerValue] = [:]
    var notes: String = ""
    var skippedToNotes = false

    func answer(for step: FeedbackStep) -> FeedbackAnswerValue? {
        answers[step]
    }

    func stars(for step: FeedbackStep) -> Int? {
        if case .stars(let value)? = answers[step] { return value }
        return nil
    }

    func single(for step: FeedbackStep) -> String? {
        if case .single(let value)? = answers[step] { return value }
        return nil
    }

    var usedAIFeatures: Bool {
        guard let raw = single(for: .aiFeatures) else { return false }
        return raw != FeedbackOptions.AIFeature.noneOfThese.rawValue
    }

    var hasLoggedTransactions: Bool {
        guard let raw = single(for: .howTheyLog) else { return false }
        return raw != FeedbackOptions.HowTheyLog.haventLogged.rawValue
    }

    var shouldShowCaptureAccuracy: Bool { hasLoggedTransactions }

    var shouldShowWhatWasWrong: Bool {
        guard let rating = stars(for: .captureAccuracy) else { return false }
        return (1 ... 2).contains(rating)
    }

    var shouldShowAIFeatureRating: Bool { usedAIFeatures }

    var hasSurveyAnswers: Bool { !answers.isEmpty }

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSubmit: Bool {
        hasSurveyAnswers || hasNotes
    }

    func encodedAnswers() -> [String: Any] {
        var payload: [String: Any] = [:]
        let surveySteps: [FeedbackStep] = [
            .uiApproval, .foundWhere, .shortcutsExplore,
            .howTheyLog, .captureAccuracy, .whatWasWrong, .aiFeatures,
            .aiFeatureRating, .proFeeling
        ]
        for step in surveySteps {
            guard let value = answers[step] else { continue }
            let answerType: String
            switch value {
            case .stars: answerType = "stars"
            case .single: answerType = "single"
            }
            payload[step.questionKey] = FeedbackAnswer(type: answerType, value: value).encode()
        }
        return payload
    }
}

@MainActor
@Observable
final class FeedbackFlow {
    var draft = FeedbackDraft()
    var hasSeenPaywall: Bool
    private(set) var scrollPulse: FeedbackScrollPulse?
    private var scrollNonce: UInt64 = 0

    init(hasSeenPaywall: Bool = PaywallSeenStore.hasSeenPaywall) {
        self.hasSeenPaywall = hasSeenPaywall
    }

    var shouldShowProFeeling: Bool {
        draft.usedAIFeatures || hasSeenPaywall || ProEntitlementCache.isPro
    }

    var canSubmit: Bool { draft.canSubmit }

    var visibleSteps: [FeedbackStep] {
        FeedbackStep.allCases.filter { isShowing($0) }
    }

    var visibleSurveySteps: [FeedbackStep] {
        visibleSteps.filter { $0 != .notes }
    }

    /// Share of visible survey questions that already have an answer.
    /// Notes are optional, so they stay out of the bar.
    var surveyProgress: Double {
        let steps = visibleSurveySteps
        guard !steps.isEmpty else { return 0 }
        let answered = steps.filter { draft.answer(for: $0) != nil }.count
        return Double(answered) / Double(steps.count)
    }

    var notesPlaceholder: String {
        "Thoughts, a bug, or a feature you want"
    }

    func nextVisibleStep(after step: FeedbackStep) -> FeedbackStep? {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: step) else { return nil }
        let nextIndex = steps.index(after: index)
        guard nextIndex < steps.endIndex else { return nil }
        return steps[nextIndex]
    }

    func isShowing(_ step: FeedbackStep) -> Bool {
        switch step {
        case .uiApproval, .foundWhere, .shortcutsExplore, .howTheyLog, .aiFeatures, .notes:
            return true
        case .captureAccuracy:
            return draft.shouldShowCaptureAccuracy
        case .whatWasWrong:
            return draft.shouldShowWhatWasWrong
        case .aiFeatureRating:
            return draft.shouldShowAIFeatureRating
        case .proFeeling:
            return shouldShowProFeeling
        }
    }

    func clearAnswer(for step: FeedbackStep) {
        draft.answers.removeValue(forKey: step)
        pruneHiddenAnswers()
    }

    func setStars(_ value: Int, for step: FeedbackStep) {
        let selecting = draft.stars(for: step) != value
        if selecting {
            draft.answers[step] = .stars(value)
        } else {
            draft.answers.removeValue(forKey: step)
        }
        pruneHiddenAnswers()
        if selecting {
            queueAdvance(from: step)
        }
    }

    func setSingle(_ id: String, for step: FeedbackStep) {
        let selecting = draft.single(for: step) != id
        if selecting {
            draft.answers[step] = .single(id)
        } else {
            draft.answers.removeValue(forKey: step)
        }
        pruneHiddenAnswers()
        if selecting {
            queueAdvance(from: step)
        }
    }

    private func pruneHiddenAnswers() {
        if !draft.shouldShowCaptureAccuracy {
            draft.answers.removeValue(forKey: .captureAccuracy)
        }
        if !draft.shouldShowWhatWasWrong {
            draft.answers.removeValue(forKey: .whatWasWrong)
        }
        if !draft.shouldShowAIFeatureRating {
            draft.answers.removeValue(forKey: .aiFeatureRating)
        }
        if !shouldShowProFeeling {
            draft.answers.removeValue(forKey: .proFeeling)
        }
    }

    private func queueAdvance(from step: FeedbackStep) {
        guard step.advancesOnAnswer, let next = nextVisibleStep(after: step) else { return }
        scrollNonce += 1
        scrollPulse = FeedbackScrollPulse(step: next, nonce: scrollNonce)
    }
}

// MARK: - Paywall seen flag

enum PaywallSeenStore {
    static let defaultsKey = "spendrift.hasSeenPaywall"

    static var hasSeenPaywall: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: defaultsKey)
    }
}
