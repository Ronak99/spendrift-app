//
//  VoiceLiveActivityController.swift
//  Spendrift
//
//  Created by Cursor on 23/03/26.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

enum VoiceLiveActivityState: String {
    case recording
    case reviewing
    case processing
    case success
    case completed
    case failed
}

final class VoiceLiveActivityController {
    #if canImport(ActivityKit)
    private var activity: Activity<VoiceLiveActivityAttributes>?
    #endif

    func start() {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = VoiceLiveActivityAttributes(title: "Voice Entry")
        let state = VoiceLiveActivityAttributes.ContentState(
            state: VoiceLiveActivityState.recording.rawValue,
            message: "Listening..."
        )
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            activity = nil
        }
        #endif
    }

    func update(state: VoiceLiveActivityState, message: String) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            let state = VoiceLiveActivityAttributes.ContentState(
                state: state.rawValue,
                message: message
            )
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        #endif
    }

    func end(message: String = "Done") {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            let state = VoiceLiveActivityAttributes.ContentState(
                state: VoiceLiveActivityState.completed.rawValue,
                message: message
            )
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }

    func failAndEnd(message: String, dismissAfter seconds: TimeInterval = 3) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            let failureState = VoiceLiveActivityAttributes.ContentState(
                state: VoiceLiveActivityState.failed.rawValue,
                message: message
            )
            await activity.update(ActivityContent(state: failureState, staleDate: nil))

            if seconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            await activity.end(ActivityContent(state: failureState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }

    func succeedAndEnd(message: String, dismissAfter seconds: TimeInterval = 3) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            let successState = VoiceLiveActivityAttributes.ContentState(
                state: VoiceLiveActivityState.success.rawValue,
                message: message
            )
            await activity.update(ActivityContent(state: successState, staleDate: nil))

            if seconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            await activity.end(ActivityContent(state: successState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }
}
