//
//  ReceiptShareInbox.swift
//  Spendrift
//
//  Cross-process handoff for receipt images shared into the app via the Share
//  Extension. The extension writes the image into the shared App Group container
//  and records a pending path; the host app consumes it on launch/foreground.
//
//  This is the image analog of `VoiceExpenseIntent.pendingImportPathKey`, but it
//  must use the App Group suite (not `UserDefaults.standard`) because the extension
//  runs in a separate process from the app.
//

import Foundation

enum ReceiptShareInbox {
    static let appGroupID = "group.com.ronakpunase.Spendrift"
    static let pendingImagePathKey = "receiptSharePendingImagePath"
    static let openURL = URL(string: "spendrift://importReceipt")!

    private static let inboxFolderName = "ReceiptShareInbox"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static func inboxDirectory() -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return nil
        }
        let dir = container.appendingPathComponent(inboxFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Called by the Share Extension. Persists the image into the App Group and records the path.
    /// Returns the written file URL on success.
    @discardableResult
    static func save(imageData: Data, fileExtension: String) -> URL? {
        guard let dir = inboxDirectory() else { return nil }
        let ext = fileExtension.isEmpty ? "img" : fileExtension
        let dest = dir.appendingPathComponent("shared-receipt-\(UUID().uuidString).\(ext)")
        do {
            try imageData.write(to: dest, options: .atomic)
        } catch {
            return nil
        }
        sharedDefaults?.set(dest.path, forKey: pendingImagePathKey)
        return dest
    }

    /// Called by the host app. Returns and clears the pending image URL if one exists on disk.
    static func consumePendingImageURL() -> URL? {
        guard let defaults = sharedDefaults,
              let path = defaults.string(forKey: pendingImagePathKey),
              !path.isEmpty else {
            return nil
        }
        defaults.removeObject(forKey: pendingImagePathKey)
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func removeFileIfPresent(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
