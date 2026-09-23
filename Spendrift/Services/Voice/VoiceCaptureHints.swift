//
//  VoiceCaptureHints.swift
//  Spendrift
//
//  Example phrases shown while voice recording, so the user has an expense in mind
//  the moment the mic opens. Copy and locale coverage ship in the bundled
//  `expense_hints.json`.
//

import Foundation

enum VoiceCaptureHints {
    /// The catalog every locale falls back to when it has no entry of its own.
    static let defaultLocaleKey = "default"

    struct Catalog: Decodable, Equatable {
        struct Entry: Decodable, Equatable {
            let scripts: [String]
        }

        let locales: [String: Entry]
    }

    /// Decoded once per launch. Empty if the file is missing or malformed, which the
    /// callers treat the same as a locale with no scripts.
    static let bundledCatalog: Catalog = {
        guard
            let url = Bundle.main.url(forResource: "expense_hints", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(Catalog.self, from: data)
        else {
            return Catalog(locales: [:])
        }
        return catalog
    }()

    static func randomScript(
        for locale: Locale = .current,
        catalog: Catalog = bundledCatalog
    ) -> String? {
        scripts(for: locale, catalog: catalog).randomElement()
    }

    /// The most specific non-empty list for `locale`: its exact language and region
    /// (`en_IN`), then any entry for the same region (a Hindi device in India still
    /// gets rupees), then `default`.
    static func scripts(for locale: Locale, catalog: Catalog) -> [String] {
        for key in lookupKeys(for: locale, catalog: catalog) {
            let scripts = cleaned(catalog.locales[key]?.scripts ?? [])
            if !scripts.isEmpty { return scripts }
        }
        return []
    }

    // MARK: - Lookup

    private static func lookupKeys(for locale: Locale, catalog: Catalog) -> [String] {
        var keys: [String] = []
        let region = locale.region?.identifier

        // Built from components rather than `locale.identifier`, which can carry
        // extensions such as `@rg=gbzzzz` that would never match a catalog key.
        if let language = locale.language.languageCode?.identifier, let region {
            keys.append("\(language)_\(region)")
        }
        if let region {
            keys += catalog.locales.keys
                .filter { $0.hasSuffix("_\(region)") }
                .sorted()
        }
        keys.append(defaultLocaleKey)
        return keys
    }

    private static func cleaned(_ scripts: [String]) -> [String] {
        scripts.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}
