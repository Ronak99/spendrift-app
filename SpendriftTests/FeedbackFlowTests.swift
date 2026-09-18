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
    func alwaysShowsCoreQuestions() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        #expect(flow.isShowing(.uiApproval))
        #expect(flow.isShowing(.foundWhere))
        #expect(flow.isShowing(.shortcutsExplore))
        #expect(flow.isShowing(.howTheyLog))
        #expect(flow.isShowing(.aiFeatures))
        #expect(flow.isShowing(.recommend))
        #expect(flow.isShowing(.notes))
        #expect(!flow.isShowing(.whichShortcuts))
        #expect(!flow.isShowing(.captureAccuracy))
        #expect(!flow.isShowing(.whatWasWrong))
        #expect(!flow.isShowing(.aiFeatureRating))
        #expect(!flow.isShowing(.proFeeling))
    }

    @Test
    func showsWhichShortcutsWhenTheyKnewAboutThem() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.ShortcutsExplore.addedAtLeastOne.rawValue, for: .shortcutsExplore)
        #expect(flow.isShowing(.whichShortcuts))

        flow.setSingle(FeedbackOptions.ShortcutsExplore.didntKnow.rawValue, for: .shortcutsExplore)
        #expect(!flow.isShowing(.whichShortcuts))
        #expect(flow.draft.answer(for: .whichShortcuts) == nil)
    }

    @Test
    func hidesCaptureWhenTheyHaveNotLogged() {
        let flow = FeedbackFlow()
        flow.toggleMulti(FeedbackOptions.HowTheyLog.haventLogged.rawValue, for: .howTheyLog)
        #expect(!flow.isShowing(.captureAccuracy))
        #expect(!flow.isShowing(.whatWasWrong))
    }

    @Test
    func showsCaptureAndWhatWasWrongForLowRating() {
        let flow = FeedbackFlow()
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        #expect(flow.isShowing(.captureAccuracy))

        flow.setStars(1, for: .captureAccuracy)
        #expect(flow.isShowing(.whatWasWrong))

        flow.setStars(4, for: .captureAccuracy)
        #expect(!flow.isShowing(.whatWasWrong))
        #expect(flow.draft.answer(for: .whatWasWrong) == nil)
    }

    @Test
    func showsAIRatingAndProWhenTheyUsedAI() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        flow.toggleMulti(FeedbackOptions.AIFeature.voiceCapture.rawValue, for: .aiFeatures)
        #expect(flow.isShowing(.aiFeatureRating))
        #expect(flow.isShowing(.proFeeling))
    }

    @Test
    func hidesProWhenNoAIAndNoPaywall() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        flow.toggleMulti(FeedbackOptions.AIFeature.noneOfThese.rawValue, for: .aiFeatures)
        #expect(!flow.isShowing(.aiFeatureRating))
        #expect(!flow.isShowing(.proFeeling))
    }

    @Test
    func showsProWhenPaywallWasSeenEvenWithoutAI() {
        let flow = FeedbackFlow(hasSeenPaywall: true)
        flow.toggleMulti(FeedbackOptions.AIFeature.noneOfThese.rawValue, for: .aiFeatures)
        #expect(!flow.isShowing(.aiFeatureRating))
        #expect(flow.isShowing(.proFeeling))
    }

    @Test
    func exclusiveMultiClearsOtherSelections() {
        let flow = FeedbackFlow()
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.speak.rawValue, for: .howTheyLog)
        flow.toggleMulti(
            FeedbackOptions.HowTheyLog.haventLogged.rawValue,
            for: .howTheyLog,
            exclusive: FeedbackOptions.HowTheyLog.haventLogged.rawValue
        )
        #expect(flow.draft.multi(for: .howTheyLog) == [FeedbackOptions.HowTheyLog.haventLogged.rawValue])
        #expect(!flow.isShowing(.captureAccuracy))
    }

    @Test
    func emptyMultiRemovesTheAnswer() {
        let flow = FeedbackFlow()
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        #expect(flow.draft.answer(for: .howTheyLog) == nil)
        #expect(!flow.canSubmit)
    }

    @Test
    func deselectingSingleRemovesTheAnswer() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.FoundWhere.youtube.rawValue, for: .foundWhere)
        flow.setSingle(FeedbackOptions.FoundWhere.youtube.rawValue, for: .foundWhere)
        #expect(flow.draft.answer(for: .foundWhere) == nil)
    }

    @Test
    func encodedAnswersOmitUnansweredSteps() {
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
        flow.setStars(1, for: .recommend)
        #expect(flow.notesPlaceholder == "What should we fix?")
    }

    @Test
    func canSubmitWithASingleAnswer() {
        let flow = FeedbackFlow()
        #expect(!flow.canSubmit)
        flow.setStars(4, for: .uiApproval)
        #expect(flow.canSubmit)
    }

    @Test
    func canSubmitWithNotesOnly() {
        let flow = FeedbackFlow()
        flow.draft.notes = "  the capture is off  "
        #expect(flow.canSubmit)
    }

    @Test
    func whitespaceNotesDoNotUnlockSubmit() {
        let flow = FeedbackFlow()
        flow.draft.notes = "   \n"
        #expect(!flow.canSubmit)
    }

    @Test
    func pruningRemovesStaleFollowUps() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.ShortcutsExplore.addedAtLeastOne.rawValue, for: .shortcutsExplore)
        flow.toggleMulti(FeedbackOptions.WhichShortcut.voiceRecordExpense.rawValue, for: .whichShortcuts)
        #expect(flow.draft.answer(for: .whichShortcuts) != nil)

        flow.setSingle(FeedbackOptions.ShortcutsExplore.didntKnow.rawValue, for: .shortcutsExplore)
        #expect(flow.draft.answer(for: .whichShortcuts) == nil)
    }

    @Test
    func canSubmitWithScreenshotOnly() {
        let flow = FeedbackFlow()
        flow.draft.screenshotData = Data("jpeg".utf8)
        #expect(flow.canSubmit)
    }

    @Test
    func normalizedNotesTrimsWhitespace() {
        #expect(FeedbackClient.normalizedNotes("  ") == nil)
        #expect(FeedbackClient.normalizedNotes(" hello ") == "hello")
    }

    @Test
    func nextVisibleStepWalksTheCorePath() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        #expect(flow.nextVisibleStep(after: .uiApproval) == .foundWhere)
        #expect(flow.nextVisibleStep(after: .foundWhere) == .shortcutsExplore)
        #expect(flow.nextVisibleStep(after: .shortcutsExplore) == .howTheyLog)
        #expect(flow.nextVisibleStep(after: .notes) == nil)
    }

    @Test
    func answeringShortcutsScrollsToTheFollowUp() {
        let flow = FeedbackFlow()
        flow.setSingle(
            FeedbackOptions.ShortcutsExplore.addedAtLeastOne.rawValue,
            for: .shortcutsExplore
        )
        #expect(flow.nextVisibleStep(after: .shortcutsExplore) == .whichShortcuts)
        #expect(flow.scrollPulse?.step == .whichShortcuts)
    }

    @Test
    func deselectingSingleDoesNotQueueAScroll() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.FoundWhere.youtube.rawValue, for: .foundWhere)
        let firstPulse = flow.scrollPulse
        #expect(firstPulse?.step == .shortcutsExplore)

        flow.setSingle(FeedbackOptions.FoundWhere.youtube.rawValue, for: .foundWhere)
        #expect(flow.scrollPulse == firstPulse)
    }

    @Test
    func multiSelectDoesNotQueueAScroll() {
        let flow = FeedbackFlow()
        flow.toggleMulti(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        #expect(flow.scrollPulse == nil)
    }

    @Test
    func surveyProgressIgnoresNotesAndTracksAnswers() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        let total = Double(flow.visibleSurveySteps.count)
        #expect(total == 6)
        #expect(flow.surveyProgress == 0)

        flow.setStars(4, for: .uiApproval)
        #expect(abs(flow.surveyProgress - (1 / total)) < 0.0001)

        flow.draft.notes = "hello"
        #expect(abs(flow.surveyProgress - (1 / total)) < 0.0001)
    }
}
