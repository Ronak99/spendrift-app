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
}
