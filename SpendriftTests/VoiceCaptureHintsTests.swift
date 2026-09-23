//
//  VoiceCaptureHintsTests.swift
//  SpendriftTests
//

import Foundation
import Testing
@testable import Spendrift

struct VoiceCaptureHintsTests {
    private static let catalog = VoiceCaptureHints.Catalog(locales: [
        "default": .init(scripts: ["50 for lunch"]),
        "en_IN": .init(scripts: ["₹250 for Lunch", "Paid 3500 for electric bill"]),
        "en_US": .init(scripts: ["$50 for lunch"])
    ])

    @Test
    func returnsScriptsForMatchingLocale() {
        let scripts = VoiceCaptureHints.scripts(for: Locale(identifier: "en_IN"), catalog: Self.catalog)
        #expect(scripts == ["₹250 for Lunch", "Paid 3500 for electric bill"])
    }

    @Test
    func ignoresLocaleIdentifierExtensions() {
        let scripts = VoiceCaptureHints.scripts(for: Locale(identifier: "en_US@calendar=gregorian"), catalog: Self.catalog)
        #expect(scripts == ["$50 for lunch"])
    }

    @Test
    func fallsBackToSameRegion() {
        let scripts = VoiceCaptureHints.scripts(for: Locale(identifier: "hi_IN"), catalog: Self.catalog)
        #expect(scripts.first == "₹250 for Lunch")
    }

    @Test
    func unknownLocaleFallsBackToDefault() {
        let scripts = VoiceCaptureHints.scripts(for: Locale(identifier: "fr_FR"), catalog: Self.catalog)
        #expect(scripts == ["50 for lunch"])
    }

    @Test
    func emptyCatalogReturnsNoScript() {
        let empty = VoiceCaptureHints.Catalog(locales: [:])
        #expect(VoiceCaptureHints.randomScript(for: Locale(identifier: "en_IN"), catalog: empty) == nil)
    }

    @Test
    func blankOnlyEntryFallsThroughToDefault() {
        let catalog = VoiceCaptureHints.Catalog(locales: [
            "default": .init(scripts: ["50 for lunch"]),
            "en_IN": .init(scripts: ["  Valid line  ", "   ", ""]),
            "en_GB": .init(scripts: ["   "])
        ])
        #expect(VoiceCaptureHints.scripts(for: Locale(identifier: "en_IN"), catalog: catalog) == ["Valid line"])
        #expect(VoiceCaptureHints.scripts(for: Locale(identifier: "en_GB"), catalog: catalog) == ["50 for lunch"])
    }

    @Test
    func bundledCatalogCoversDefault() {
        #expect(!(VoiceCaptureHints.bundledCatalog.locales["default"]?.scripts.isEmpty ?? true))
    }
}
