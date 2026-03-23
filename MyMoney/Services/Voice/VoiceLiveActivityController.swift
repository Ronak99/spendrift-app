//
//  VoiceLiveActivityController.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

enum VoiceLiveActivityState: String {
    case recording
    case transcribing
    case saving
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
        let content = VoiceLiveActivityAttributes.ContentState(
            state: VoiceLiveActivityState.recording.rawValue,
            message: "Listening..."
        )
        do {
            activity = try Activity.request(attributes: attributes, contentState: content)
        } catch {
            activity = nil
        }
        #endif
    }

    func update(state: VoiceLiveActivityState, message: String) {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            let content = VoiceLiveActivityAttributes.ContentState(
                state: state.rawValue,
                message: message
            )
            await activity.update(using: content)
        }
        #endif
    }

    func end(message: String = "Done") {
        #if canImport(ActivityKit)
        guard let activity else { return }
        Task {
            let content = VoiceLiveActivityAttributes.ContentState(
                state: VoiceLiveActivityState.completed.rawValue,
                message: message
            )
            await activity.end(using: content, dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }
}
