//
//  MessageInboxSettings.swift
//  Spendrift
//
//  Health signal for SMS auto-logging (last capture time).
//  Capture + drain run whenever the Shortcuts automation is set up; no opt-in toggle.
//

import Foundation

enum MessageInboxSettings {
    static let lastCapturedAtKey = "messageInboxLastCapturedAt"

    private static var suite: UserDefaults {
        UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    static var lastCapturedAt: Date? {
        get {
            let interval = suite.double(forKey: lastCapturedAtKey)
            guard interval > 0 else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            if let newValue {
                suite.set(newValue.timeIntervalSince1970, forKey: lastCapturedAtKey)
            } else {
                suite.removeObject(forKey: lastCapturedAtKey)
            }
        }
    }

    static func recordCapture(at date: Date = Date()) {
        lastCapturedAt = date
    }
}

/// App Group JSON fallback when the SwiftData inbox cannot be opened from the intent.
enum MessageInboxFallback {
    private static let key = "messageInboxFallbackQueue"

    struct Item: Codable {
        let id: UUID
        let body: String
        let sender: String
        let fingerprint: String
        let capturedAt: Date
    }

    private static var suite: UserDefaults {
        UserDefaults(suiteName: IntentSwiftData.appGroupID) ?? .standard
    }

    static func enqueue(
        body: String,
        sender: String,
        fingerprint: String,
        capturedAt: Date
    ) {
        var items = load()
        items.append(
            Item(
                id: UUID(),
                body: body,
                sender: sender,
                fingerprint: fingerprint,
                capturedAt: capturedAt
            )
        )
        save(items)
    }

    static func consumeAll() -> [Item] {
        let items = load()
        suite.removeObject(forKey: key)
        return items
    }

    /// Non-destructive read for the debug inbox screen.
    static func peekAll() -> [Item] {
        load()
    }

    private static func load() -> [Item] {
        guard let data = suite.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }

    private static func save(_ items: [Item]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        suite.set(data, forKey: key)
    }
}
