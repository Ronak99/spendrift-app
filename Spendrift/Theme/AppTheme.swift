//
//  AppTheme.swift
//  Spendrift
//
//  Semantic surface colors shared across list screens, empty states, and cards.
//  Change values here to restyle the app without hunting through individual views.
//

import SwiftUI
import UIKit

enum AppTheme {
    /// Spendrift cyan. Static wash on Home and Settings, plus Settings chrome.
    static let atmosphere = Color(hex: "#06DEFF")

    /// Fixed accent for Settings enamel, toggles, and other app-wide highlights.
    static let accent = atmosphere

    /// Insertion caret. The app is dark-only, so one white caret stays visible on every field.
    static let cursor = Color.white

    /// Gray canvas behind grouped lists, empty states, and summary headers.
    static let listBackground = Color(uiColor: .systemGroupedBackground)

    /// Raised surface inside grouped lists: rows, inset cards, and settings groups.
    static let listGroupBackground = Color(uiColor: .secondarySystemGroupedBackground)

    // MARK: Home chrome
    //
    // Near-black canvas, lifted card surfaces and the atmosphere's blue wash behind
    // the status bar and title. One token per surface so the whole shell restyles
    // from here.

    /// Page behind every Home pane.
    static let canvas = scheme(dark: "#17171C", light: "#F2F2F7")

    /// Raised card: Home blocks, ledger rows, search results.
    static let card = scheme(dark: "#202027", light: "#FFFFFF")

    /// Second surface: glyph plates, pressed chips, the "now" month in the picker.
    static let cardAlternate = scheme(dark: "#2B2B33", light: "#EDEDF2")

    /// Fill of the Home search bar, which sits on the atmosphere wash.
    static let searchField = scheme(dark: "#26261F", light: "#FFFFFF")

    /// Edge of the Home search bar.
    static let searchFieldEdge = scheme(dark: "#FFFFFF", light: "#000000", darkAlpha: 0.14, lightAlpha: 0.1)

    /// Divider inside cards and under the tab strip.
    static let hairline = scheme(dark: "#FFFFFF", light: "#000000", darkAlpha: 0.08, lightAlpha: 0.07)

    /// Translucent plate behind the tray orbs and segmented controls.
    static let glass = scheme(dark: "#FFFFFF", light: "#FFFFFF", darkAlpha: 0.1, lightAlpha: 0.72)

    /// Hairline on glass plates.
    static let glassEdge = scheme(dark: "#FFFFFF", light: "#000000", darkAlpha: 0.16, lightAlpha: 0.06)

    /// Primary ink.
    static let ink = scheme(dark: "#FFFFFF", light: "#111111")

    /// Secondary ink: captions, labels, subtitles.
    static let inkSecondary = Color(uiColor: .secondaryLabel)

    /// Tertiary ink: legends, deltas, chevrons.
    static let inkTertiary = Color(uiColor: .tertiaryLabel)

    /// Fill of the one primary action on screen (Add transaction, Save, Set one).
    static let actionBackground = scheme(dark: "#FFFFFF", light: "#111111", darkAlpha: 0.92, lightAlpha: 1)

    /// Ink on `actionBackground`.
    static let actionForeground = scheme(dark: "#111111", light: "#FFFFFF")

    /// Money going out.
    static let expense = Color(hex: "#FF6B6B")

    /// Money coming in.
    static let income = Color(hex: "#4FC3A1")

    /// Trend lines and sparklines that carry no expense / income meaning.
    static let trend = scheme(dark: "#4FB8E8", light: "#2E90C9")

    /// Voice capture.
    static let microphone = scheme(dark: "#F57873", light: "#C23D3B")

    private static func scheme(
        dark: String,
        light: String,
        darkAlpha: Double = 1,
        lightAlpha: Double = 1
    ) -> Color {
        let darkColor = UIColor(Color(hex: dark).opacity(darkAlpha))
        let lightColor = UIColor(Color(hex: light).opacity(lightAlpha))
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}
