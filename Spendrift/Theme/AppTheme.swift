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
    /// Fixed accent for Settings chrome, tab tint, and other app-wide highlights.
    static let accent = Color(hex: "#3A7BFF")

    /// Gray canvas behind grouped lists, empty states, and summary headers.
    static let listBackground = Color(uiColor: .systemGroupedBackground)

    /// Raised surface inside grouped lists: rows, inset cards, and settings groups.
    static let listGroupBackground = Color(uiColor: .secondarySystemGroupedBackground)
}
