//
//  FeedbackFlow.swift
//  Spendrift
//
//  Multi-step feedback survey state machine. Branching follows
//  Spendrift/docs/FEEDBACK_FORM.md.
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

    var isSurveyStep: Bool { self != .notes }
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

    var shouldShowProFeeling: Bool {
        usedAIFeatures || PaywallSeenStore.hasSeenPaywall || ProEntitlementCache.isPro
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
    private(set) var currentStep: FeedbackStep = .uiApproval
    private var history: [FeedbackStep] = []
    var draft = FeedbackDraft()
    var hasSeenPaywall: Bool

    init(hasSeenPaywall: Bool = PaywallSeenStore.hasSeenPaywall) {
        self.hasSeenPaywall = hasSeenPaywall || PaywallSeenStore.hasSeenPaywall
    }

    var canProceed: Bool {
        switch currentStep {
        case .notes:
            return true
        case .uiApproval, .captureAccuracy, .aiFeatureRating, .recommend:
            return draft.stars(for: currentStep) != nil
        case .foundWhere, .shortcutsExplore, .whatWasWrong, .proFeeling:
            return draft.single(for: currentStep) != nil
        case .whichShortcuts, .howTheyLog, .aiFeatures:
            return !draft.multi(for: currentStep).isEmpty
        }
    }

    var showsSkipToNotes: Bool { currentStep.isSurveyStep }

    var notesPlaceholder: String {
        if let rating = draft.stars(for: .recommend), (0 ... 2).contains(rating) {
            return "What should we fix?"
        }
        return "Thoughts, a bug, or a feature you want"
    }

    func setStars(_ value: Int, for step: FeedbackStep) {
        draft.answers[step] = .stars(value)
    }

    func setSingle(_ id: String, for step: FeedbackStep) {
        draft.answers[step] = .single(id)
    }

    func toggleMulti(_ id: String, for step: FeedbackStep, exclusive: String? = nil) {
        var selected = draft.multi(for: step)
        if let exclusive, id == exclusive {
            selected = [exclusive]
        } else {
            if let exclusive { selected.remove(exclusive) }
            if selected.contains(id) {
                selected.remove(id)
            } else {
                selected.insert(id)
            }
        }
        draft.answers[step] = .multi(selected)
    }

    func advance() {
        guard let next = nextStep(after: currentStep) else { return }
        history.append(currentStep)
        currentStep = next
    }

    func goBack(onFirstStep: () -> Void) {
        if history.isEmpty {
            onFirstStep()
            return
        }
        currentStep = history.removeLast()
    }

    func skipToNotes() {
        draft.skippedToNotes = true
        if currentStep != .notes {
            history.append(currentStep)
        }
        currentStep = .notes
    }

    func nextStep(after step: FeedbackStep) -> FeedbackStep? {
        switch step {
        case .uiApproval:
            return .foundWhere
        case .foundWhere:
            return .shortcutsExplore
        case .shortcutsExplore:
            return draft.shouldShowWhichShortcuts ? .whichShortcuts : .howTheyLog
        case .whichShortcuts:
            return .howTheyLog
        case .howTheyLog:
            return draft.shouldShowCaptureAccuracy ? .captureAccuracy : .recommend
        case .captureAccuracy:
            return draft.shouldShowWhatWasWrong ? .whatWasWrong : .aiFeatures
        case .whatWasWrong:
            return .aiFeatures
        case .aiFeatures:
            if draft.shouldShowAIFeatureRating {
                return .aiFeatureRating
            }
            return draft.shouldShowProFeeling ? .proFeeling : .recommend
        case .aiFeatureRating:
            return .proFeeling
        case .proFeeling:
            return .recommend
        case .recommend:
            return .notes
        case .notes:
            return nil
        }
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
