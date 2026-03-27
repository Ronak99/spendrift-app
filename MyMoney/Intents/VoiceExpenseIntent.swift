//
//  VoiceExpenseIntent.swift
//  MyMoney
//
//  Created by Cursor on 27/03/26.
//

import AppIntents
import Foundation

struct VoiceExpenseIntent: AppIntent {
    private static let launchTriggerKey = "voiceExpenseIntentLaunchAt"

    static let title: LocalizedStringResource = "Record Voice Expense"
    static let description = IntentDescription("Start quick voice expense capture.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.launchTriggerKey)
        return .result()
    }
}
