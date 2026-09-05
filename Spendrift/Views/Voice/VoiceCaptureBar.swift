//
//  VoiceCaptureBar.swift
//  Spendrift
//
//  Created by Cursor on 05/09/26.
//

import SwiftData
import SwiftUI

/// Hosts the inline voice capture bar above the tab bar for screens that do not already
/// compose it into a richer bottom overlay. The controller is owned by `ContentView`, so a
/// capture started from the tab bar CTA stays visible no matter which tab the user is on.
private struct VoiceCaptureBarModifier: ViewModifier {
    let controller: VoiceInlineCaptureController
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                VoiceInlineRecordingBar(
                    controller: controller,
                    accounts: accounts,
                    categories: categories.sortedByLastUsage()
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: controller.displayState)
    }
}

extension View {
    func voiceCaptureBar(controller: VoiceInlineCaptureController) -> some View {
        modifier(VoiceCaptureBarModifier(controller: controller))
    }
}
