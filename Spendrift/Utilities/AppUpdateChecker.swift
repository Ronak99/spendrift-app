//
//  AppUpdateChecker.swift
//  Spendrift
//
//  Fetches the latest App Store version via the iTunes lookup API and classifies
//  the delta against the installed build as mandatory, optional, or ignorable.
//

import Foundation
import Observation

// MARK: - Update kind

enum UpdateKind {
    /// Minor version bump (1.0.0 → 1.x.0) — show a dismissible sheet.
    case optional
    /// Major version bump (1.0.0 → x.0.0) — show a blocking, indismissible sheet.
    case mandatory
}

// MARK: - Checker

@Observable
final class AppUpdateChecker {

    // MARK: Outputs

    /// Non-nil only when an optional or mandatory update is available.
    private(set) var updateKind: UpdateKind?
    /// Direct App Store URL for the app (`trackViewUrl` from iTunes lookup).
    private(set) var storeURL: URL?
    /// The version string returned by the store (e.g. "1.1.0").
    private(set) var latestVersion: String?

    // MARK: Constants

    private let bundleID = "com.ronakpunase.Spendrift"

    // MARK: Public API

    /// Perform the lookup. Safe to call multiple times; only the first call does network work.
    func check() async {
        guard updateKind == nil, latestVersion == nil else { return }

        guard
            let currentRaw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let current = SemanticVersion(currentRaw)
        else { return }

        guard let latest = await fetchStoreVersion() else { return }

        latestVersion = latest.version.raw

        let kind = classify(current: current, latest: latest.version)
        // Patch bumps are ignorable — leave updateKind nil.
        if let kind {
            updateKind = kind
            storeURL = latest.trackViewURL
        }
    }

    // MARK: Private

    private struct StoreResult {
        let version: SemanticVersion
        let trackViewURL: URL?
    }

    private func fetchStoreVersion() async -> StoreResult? {
        guard
            let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&country=us")
        else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let first = results.first,
                let versionString = first["version"] as? String,
                let version = SemanticVersion(versionString)
            else { return nil }

            let trackViewURL = (first["trackViewUrl"] as? String).flatMap(URL.init(string:))
            return StoreResult(version: version, trackViewURL: trackViewURL)
        } catch {
            return nil
        }
    }

    private func classify(current: SemanticVersion, latest: SemanticVersion) -> UpdateKind? {
        if latest.major > current.major { return .mandatory }
        if latest.minor > current.minor { return .optional }
        // patch bump → ignorable
        return nil
    }
}

// MARK: - Semantic version

struct SemanticVersion {
    let major: Int
    let minor: Int
    let patch: Int
    let raw: String

    init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        major = parts.count > 0 ? parts[0] : 0
        minor = parts.count > 1 ? parts[1] : 0
        patch = parts.count > 2 ? parts[2] : 0
        raw = trimmed
    }
}
