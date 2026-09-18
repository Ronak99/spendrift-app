//
//  FeedbackFlow.swift
//  Spendrift
//
//  Single-page feedback survey state. Branching still follows
//  Spendrift/docs/FEEDBACK_FORM.md, but questions appear or hide in place
//  instead of advancing a wizard.
//

import Foundation

// MARK: - Steps

enum FeedbackStep: Equatable, Hashable, CaseIterable {
    case uiApproval
    case foundWhere
    case shortcutsExplore
    case whichShortcuts
    case howTheyLog
    case captureAccuracy
    case whatWasWrong
    case aiFeatures
    case aiFeatureRating
    case proFeeling
    case recommend
    case notes
}

// MARK: - Answer types

enum FeedbackAnswerValue: Equatable {
    case stars(Int)
    case single(String)
    case multi(Set<String>)
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
        case .multi(let ids):
            return ["type": type, "value": Array(ids).sorted()]
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
        case reddit, youtube, appStore = "app_store", other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .reddit: "Reddit"
            case .youtube: "YouTube"
            case .appStore: "App Store"
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
            case .openedExploreOrOnboarding: "Yes, I opened Explore or saw them in onboarding"
            case .sawButDidntAdd: "I saw them but didn't add any"
            case .addedAtLeastOne: "I added at least one shortcut"
            case .didntKnow: "I didn't know they existed"
            }
        }
    }

    enum WhichShortcut: String, CaseIterable, Identifiable {
        case voiceRecordExpense = "voice_record_expense"
        case logExpenseAmount = "log_expense_amount"
        case bankSmsAutomation = "bank_sms_automation"
        case homeScreenWidget = "home_screen_widget"
        case noneOfThese = "none_of_these"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .voiceRecordExpense: "Voice Record Expense"
            case .logExpenseAmount: "Log Expense Amount"
            case .bankSmsAutomation: "Bank SMS automation"
            case .homeScreenWidget: "Home screen widget"
            case .noneOfThese: "None of these"
            }
        }
    }

    enum HowTheyLog: String, CaseIterable, Identifiable {
        case typeInApp = "type_in_app"
        case speak
        case scanReceipt = "scan_receipt"
        case importStatement = "import_statement"
        case bankSms = "bank_sms"
        case widgetOrShortcutOnly = "widget_or_shortcut_only"
        case haventLogged = "havent_logged"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .typeInApp: "Type in the app"
            case .speak: "Speak (in app or via shortcut)"
            case .scanReceipt: "Scan a receipt"
            case .importStatement: "Import a bank statement (PDF)"
            case .bankSms: "Bank SMS"
            case .widgetOrShortcutOnly: "Widget or Shortcut only"
            case .haventLogged: "Haven't logged one yet"
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
            case .wrongAmount: "Wrong amount"
            case .wrongCategory: "Wrong category"
            case .wrongAccount: "Wrong account"
            case .failedReenter: "It failed / I had to re-enter"
            case .notSure: "Not sure"
            }
        }
    }

    enum AIFeature: String, CaseIterable, Identifiable {
        case voiceCapture = "voice_capture"
        case receiptScan = "receipt_scan"
        case bankStatementImport = "bank_statement_import"
        case bankSmsImport = "bank_sms_import"
        case noneOfThese = "none_of_these"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .voiceCapture: "Voice capture"
            case .receiptScan: "Receipt scan"
            case .bankStatementImport: "Bank statement import"
            case .bankSmsImport: "Bank SMS import"
            case .noneOfThese: "None of these"
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
            case .worthPaying: "Worth paying for"
            case .freeEnough: "Free limits are enough"
            case .noSubscription: "I don't want a subscription"
            case .alreadySubscribe: "I already subscribe"
            case .haventHitPaywall: "Haven't hit the paywall"
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
        case .whichShortcuts: "which_shortcuts"
        case .howTheyLog: "how_they_log"
        case .captureAccuracy: "capture_accuracy"
        case .whatWasWrong: "what_was_wrong"
        case .aiFeatures: "ai_features"
        case .aiFeatureRating: "ai_feature_rating"
        case .proFeeling: "pro_feeling"
        case .recommend: "recommend"
        case .notes: "notes"
        }
    }

    var question: String {
        switch self {
        case .uiApproval: "How does the app look and feel?"
        case .foundWhere: "Where did you find Spendrift?"
        case .shortcutsExplore: "Have you looked at the shortcuts Spendrift offers?"
        case .whichShortcuts: "Which of these did you set up?"
        case .howTheyLog: "How do you actually log spending in Spendrift?"
        case .captureAccuracy: "When you log something, how often does Spendrift get it right?"
        case .whatWasWrong: "What was wrong most often?"
        case .aiFeatures: "Have you tried any of Spendrift's AI features?"
        case .aiFeatureRating: "How was that feature?"
        case .proFeeling: "How do you feel about Pro?"
        case .recommend: "Would you recommend Spendrift to someone like you?"
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
        case .notes: "Optional"
        default: nil
        }
    }

    /// Single-choice and star questions auto-advance. Multi-select stays put
    /// so the person can pick more than one option.
    var advancesOnAnswer: Bool {
        switch self {
        case .whichShortcuts, .howTheyLog, .aiFeatures, .notes:
            false
        default:
            true
        }
    }
}

extension FeedbackStep: Identifiable {
    var id: Self { self }
}

// MARK: - Draft + flow

struct FeedbackDraft: Equatable {
    var answers: [FeedbackStep: FeedbackAnswerValue] = [:]
    var notes: String = ""
    var screenshotData: Data?
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

    func multi(for step: FeedbackStep) -> Set<String> {
        if case .multi(let value)? = answers[step] { return value }
        return []
    }

    var usedAIFeatures: Bool {
        let selected = multi(for: .aiFeatures)
        return !selected.isEmpty && !selected.contains(FeedbackOptions.AIFeature.noneOfThese.rawValue)
    }

    var hasLoggedTransactions: Bool {
        !multi(for: .howTheyLog).contains(FeedbackOptions.HowTheyLog.haventLogged.rawValue)
            && !multi(for: .howTheyLog).isEmpty
    }

    var shouldShowWhichShortcuts: Bool {
        guard let raw = single(for: .shortcutsExplore) else { return false }
        return raw != FeedbackOptions.ShortcutsExplore.didntKnow.rawValue
    }

    var shouldShowCaptureAccuracy: Bool { hasLoggedTransactions }

    var shouldShowWhatWasWrong: Bool {
        guard let rating = stars(for: .captureAccuracy) else { return false }
        return (0 ... 2).contains(rating)
    }

    var shouldShowAIFeatureRating: Bool { usedAIFeatures }

    var hasSurveyAnswers: Bool { !answers.isEmpty }

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSubmit: Bool {
        hasSurveyAnswers || hasNotes || screenshotData != nil
    }

    func encodedAnswers() -> [String: Any] {
        var payload: [String: Any] = [:]
        let surveySteps: [FeedbackStep] = [
            .uiApproval, .foundWhere, .shortcutsExplore, .whichShortcuts,
            .howTheyLog, .captureAccuracy, .whatWasWrong, .aiFeatures,
            .aiFeatureRating, .proFeeling, .recommend
        ]
        for step in surveySteps {
            guard let value = answers[step] else { continue }
            let answerType: String
            switch value {
            case .stars: answerType = "stars"
            case .single: answerType = "single"
            case .multi: answerType = "multi"
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
        if let rating = draft.stars(for: .recommend), (0 ... 2).contains(rating) {
            return "What should we fix?"
        }
        return "Thoughts, a bug, or a feature you want"
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
        case .uiApproval, .foundWhere, .shortcutsExplore, .howTheyLog, .aiFeatures, .recommend, .notes:
            return true
        case .whichShortcuts:
            return draft.shouldShowWhichShortcuts
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

    func toggleMulti(_ id: String, for step: FeedbackStep, exclusive: String? = nil) {
        var selected = draft.multi(for: step)
        if let exclusive, id == exclusive {
            selected = selected == [exclusive] ? [] : [exclusive]
        } else {
            if let exclusive { selected.remove(exclusive) }
            if selected.contains(id) {
                selected.remove(id)
            } else {
                selected.insert(id)
            }
        }
        if selected.isEmpty {
            draft.answers.removeValue(forKey: step)
        } else {
            draft.answers[step] = .multi(selected)
        }
        pruneHiddenAnswers()
    }

    private func pruneHiddenAnswers() {
        if !draft.shouldShowWhichShortcuts {
            draft.answers.removeValue(forKey: .whichShortcuts)
        }
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
