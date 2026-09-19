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
        #expect(flow.isShowing(.notes))
        #expect(!flow.isShowing(.captureAccuracy))
        #expect(!flow.isShowing(.whatWasWrong))
        #expect(!flow.isShowing(.aiFeatureRating))
        #expect(!flow.isShowing(.proFeeling))
    }

    @Test
    func hidesCaptureWhenTheyHaveNotLogged() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.HowTheyLog.haventLogged.rawValue, for: .howTheyLog)
        #expect(!flow.isShowing(.captureAccuracy))
        #expect(!flow.isShowing(.whatWasWrong))
    }

    @Test
    func showsCaptureAndWhatWasWrongForLowRating() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
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
        flow.setSingle(FeedbackOptions.AIFeature.voiceCapture.rawValue, for: .aiFeatures)
        #expect(flow.isShowing(.aiFeatureRating))
        #expect(flow.isShowing(.proFeeling))
    }

    @Test
    func hidesProWhenNoAIAndNoPaywall() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        flow.setSingle(FeedbackOptions.AIFeature.noneOfThese.rawValue, for: .aiFeatures)
        #expect(!flow.isShowing(.aiFeatureRating))
        #expect(!flow.isShowing(.proFeeling))
    }

    @Test
    func showsProWhenPaywallWasSeenEvenWithoutAI() {
        let flow = FeedbackFlow(hasSeenPaywall: true)
        flow.setSingle(FeedbackOptions.AIFeature.noneOfThese.rawValue, for: .aiFeatures)
        #expect(!flow.isShowing(.aiFeatureRating))
        #expect(flow.isShowing(.proFeeling))
    }

    @Test
    func selectingAnotherSingleReplacesThePreviousAnswer() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.setSingle(FeedbackOptions.HowTheyLog.speak.rawValue, for: .howTheyLog)
        #expect(flow.draft.single(for: .howTheyLog) == FeedbackOptions.HowTheyLog.speak.rawValue)
        #expect(flow.isShowing(.captureAccuracy))

        flow.setSingle(FeedbackOptions.HowTheyLog.haventLogged.rawValue, for: .howTheyLog)
        #expect(flow.draft.single(for: .howTheyLog) == FeedbackOptions.HowTheyLog.haventLogged.rawValue)
        #expect(!flow.isShowing(.captureAccuracy))
    }

    @Test
    func emptySingleRemovesTheAnswer() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.setSingle(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
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
        draft.answers[.howTheyLog] = .single(FeedbackOptions.HowTheyLog.typeInApp.rawValue)
        let encoded = draft.encodedAnswers()
        #expect(encoded.keys.contains("ui_approval"))
        #expect(encoded.keys.contains("found_where"))
        #expect(encoded.keys.contains("how_they_log"))
        #expect(!encoded.keys.contains("capture_accuracy"))

        let howTheyLog = encoded["how_they_log"] as? [String: Any]
        #expect(howTheyLog?["type"] as? String == "single")
        #expect(howTheyLog?["value"] as? String == FeedbackOptions.HowTheyLog.typeInApp.rawValue)
    }

    @Test
    func notesPlaceholderStaysFixed() {
        let flow = FeedbackFlow()
        #expect(flow.notesPlaceholder == "Thoughts, a bug, or a feature you want")
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
        flow.setSingle(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        flow.setStars(1, for: .captureAccuracy)
        #expect(flow.draft.answer(for: .captureAccuracy) != nil)

        flow.setSingle(FeedbackOptions.HowTheyLog.haventLogged.rawValue, for: .howTheyLog)
        #expect(flow.draft.answer(for: .captureAccuracy) == nil)
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
    func answeringShortcutsScrollsToHowTheyLog() {
        let flow = FeedbackFlow()
        flow.setSingle(
            FeedbackOptions.ShortcutsExplore.addedAtLeastOne.rawValue,
            for: .shortcutsExplore
        )
        #expect(flow.nextVisibleStep(after: .shortcutsExplore) == .howTheyLog)
        #expect(flow.scrollPulse?.step == .howTheyLog)
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
    func answeringHowTheyLogScrollsToTheFollowUp() {
        let flow = FeedbackFlow()
        flow.setSingle(FeedbackOptions.HowTheyLog.typeInApp.rawValue, for: .howTheyLog)
        #expect(flow.nextVisibleStep(after: .howTheyLog) == .captureAccuracy)
        #expect(flow.scrollPulse?.step == .captureAccuracy)
    }

    @Test
    func surveyProgressIgnoresNotesAndTracksAnswers() {
        let flow = FeedbackFlow(hasSeenPaywall: false)
        let total = Double(flow.visibleSurveySteps.count)
        #expect(total == 5)
        #expect(flow.surveyProgress == 0)

        flow.setStars(4, for: .uiApproval)
        #expect(abs(flow.surveyProgress - (1 / total)) < 0.0001)

        flow.draft.notes = "hello"
        #expect(abs(flow.surveyProgress - (1 / total)) < 0.0001)
    }
}
