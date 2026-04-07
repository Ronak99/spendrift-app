//
//  VoiceExpenseIntent.swift
//  Spendrift
//
//  Created by Cursor on 27/03/26.
//

import AppIntents
import Foundation
struct VoiceExpenseIntent: AppIntent {
    static let launchTriggerKey = "voiceExpenseIntentLaunchAt"
    static let pendingImportPathKey = "voiceExpenseIntentPendingImportPath"

    static let title: LocalizedStringResource = "Record Voice Expense"
    static let description = IntentDescription(
        "Capture or process a voice expense. In Shortcuts, add Recorded Audio from Record Audio to use an existing clip."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "Recorded Audio",
        description: "Optional recording from Shortcuts (e.g. output of Record Audio)."
    )
    var audio: IntentFile?

    static var parameterSummary: some ParameterSummary {
        When(\VoiceExpenseIntent.$audio, .hasAnyValue) {
            Summary("Process voice expense from \(\.$audio)")
        } otherwise: {
            Summary("Record voice expense") {
                \.$audio
            }
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let audio {
            try Self.persistShortcutImport(from: audio)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.pendingImportPathKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.launchTriggerKey)
        }
        NotificationCenter.default.post(name: .voiceExpenseIntentTriggered, object: nil)
        return .result()
    }

    private static func persistShortcutImport(from audio: IntentFile) throws {
        guard let src = audio.fileURL else { return }
        let accessed = src.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                src.stopAccessingSecurityScopedResource()
            }
        }

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let ext = src.pathExtension
        let dest = caches.appendingPathComponent("shortcut-voice-\(UUID().uuidString).\(ext)")

        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: src, to: dest)

        UserDefaults.standard.removeObject(forKey: Self.launchTriggerKey)
        UserDefaults.standard.set(dest.path, forKey: Self.pendingImportPathKey)
    }
}
