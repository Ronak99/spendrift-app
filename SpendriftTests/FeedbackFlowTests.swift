//
//  FeedbackFlowTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

@MainActor
struct FeedbackFlowTests {

    @Test
    func typicalPathIncludesNotes() {
        let flow = FeedbackFlow(hasSeenPaywall: true)
        #expect(flow.currentStep == .uiApproval)

        flow.setStars(4, for: .uiApproval)
        flow.advance()
        flow.setSingle(FeedbackOptions.FoundWhere.youtube.rawValue, for: .foundWhere)
        flow.advance()
        flow.setSingle(FeedbackOptions.ShortcutsExplore.addedAtLeastOne.rawValue, for: .shortcutsExplore)
        flow.advance()
        #expect(flow.currentStep == .whichShortcuts)

        flow.toggleMulti(FeedbackOptions.WhichShortcut.voiceRecordExpense.rawValue, for: .whichShortcuts)
        flow.advance()
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.advance()
        #expect(flow.currentStep == .captureAccuracy)

        flow.setStars(4, for: .captureAccuracy)
        flow.advance()
        #expect(flow.currentStep == .aiFeatures)

        flow.toggleMulti(FeedbackOptions.AIFeature.voiceCapture.rawValue, for: .aiFeatures)
        flow.advance()
        #expect(flow.currentStep == .aiFeatureRating)

        flow.setStars(5, for: .aiFeatureRating)
        flow.advance()
        #expect(flow.currentStep == .proFeeling)

        flow.setSingle(FeedbackOptions.ProFeeling.worthPaying.rawValue, for: .proFeeling)
        flow.advance()
        flow.setStars(5, for: .recommend)
        flow.advance()
        #expect(flow.currentStep == .notes)
    }

    @Test
    func skipsWhichShortcutsWhenDidntKnow() {
        let flow = FeedbackFlow()
        flow.setStars(3, for: .uiApproval)
        flow.advance()
        flow.setSingle(FeedbackOptions.FoundWhere.reddit.rawValue, for: .foundWhere)
        flow.advance()
        flow.setSingle(FeedbackOptions.ShortcutsExplore.didntKnow.rawValue, for: .shortcutsExplore)
        flow.advance()
        #expect(flow.currentStep == .howTheyLog)
    }

    @Test
    func skipsCaptureAndAIWhenNeverLogged() {
        let flow = FeedbackFlow()
        advanceToHowTheyLog(flow)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.haventLogged.rawValue, for: .howTheyLog)
        flow.advance()
        #expect(flow.currentStep == .recommend)
    }

    @Test
    func showsWhatWasWrongForLowCaptureRating() {
        let flow = FeedbackFlow()
        advanceToHowTheyLog(flow)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.advance()
        flow.setStars(1, for: .captureAccuracy)
        flow.advance()
        #expect(flow.currentStep == .whatWasWrong)
    }

    @Test
    func skipsProWhenNoAIAndNoPaywall() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        advanceToHowTheyLog(flow)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.speak.rawValue, for: .howTheyLog)
        flow.advance()
        flow.setStars(4, for: .captureAccuracy)
        flow.advance()
        flow.toggleMulti(FeedbackOptions.AIFeature.noneOfThese.rawValue, for: .aiFeatures)
        flow.advance()
        #expect(flow.currentStep == .recommend)
    }

    @Test
    func skipToNotesSetsFlagAndLandsOnNotes() {
        let flow = FeedbackFlow()
        flow.setStars(2, for: .uiApproval)
        flow.skipToNotes()
        #expect(flow.currentStep == .notes)
        #expect(flow.draft.skippedToNotes)
    }

    @Test
    func backStackReturnsToPreviousStep() {
        let flow = FeedbackFlow()
        flow.setStars(2, for: .uiApproval)
        flow.advance()
        flow.setSingle(FeedbackOptions.FoundWhere.other.rawValue, for: .foundWhere)
        var dismissed = false
        flow.goBack {}
        #expect(flow.currentStep == .uiApproval)
        flow.goBack { dismissed = true }
        #expect(dismissed)
    }

    @Test
    func exclusiveMultiClearsOtherSelections() {
        let flow = FeedbackFlow()
        advanceToHowTheyLog(flow)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.speak.rawValue, for: .howTheyLog)
        flow.toggleMulti(
            FeedbackOptions.HowTheyLog.haventLogged.rawValue,
            for: .howTheyLog,
            exclusive: FeedbackOptions.HowTheyLog.haventLogged.rawValue
        )
        #expect(flow.draft.multi(for: .howTheyLog) == [FeedbackOptions.HowTheyLog.haventLogged.rawValue])
    }

    @Test
    func encodedAnswersOmitUnvisitedSteps() {
        var draft = FeedbackDraft()
        draft.answers[.uiApproval] = .stars(5)
        draft.answers[.foundWhere] = .single(FeedbackOptions.FoundWhere.appStore.rawValue)
        let encoded = draft.encodedAnswers()
        #expect(encoded.keys.contains("ui_approval"))
        #expect(encoded.keys.contains("found_where"))
        #expect(!encoded.keys.contains("which_shortcuts"))
    }

    @Test
    func notesPlaceholderChangesForLowRecommendScore() {
        let flow = FeedbackFlow()
        advanceToRecommend(flow)
        flow.setStars(1, for: .recommend)
        flow.advance()
        #expect(flow.notesPlaceholder == "What should we fix?")
    }

    @Test
    func normalizedNotesTrimsWhitespace() {
        #expect(FeedbackClient.normalizedNotes("  ") == nil)
        #expect(FeedbackClient.normalizedNotes(" hello ") == "hello")
    }

    // MARK: - Helpers

    private func advanceToHowTheyLog(_ flow: FeedbackFlow) {
        flow.setStars(3, for: .uiApproval)
        flow.advance()
        flow.setSingle(FeedbackOptions.FoundWhere.youtube.rawValue, for: .foundWhere)
        flow.advance()
        flow.setSingle(FeedbackOptions.ShortcutsExplore.didntKnow.rawValue, for: .shortcutsExplore)
        flow.advance()
        #expect(flow.currentStep == .howTheyLog)
    }

    private func advanceToRecommend(_ flow: FeedbackFlow) {
        advanceToHowTheyLog(flow)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.haventLogged.rawValue, for: .howTheyLog)
        flow.advance()
        #expect(flow.currentStep == .recommend)
    }
}
