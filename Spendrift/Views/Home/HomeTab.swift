//
//  HomeTab.swift
//  Spendrift
//
//  The four screens behind the Home tab strip. Each is its own pane, not a
//  scroll target, and the title bar follows the selected one.
//

import Foundation

enum HomeTab: String, CaseIterable, Identifiable {
    case all
    case transactions
    case accounts
    case categories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Home"
        case .transactions: "Transactions"
        case .accounts: "Accounts"
        case .categories: "Categories"
        }
    }

    var symbol: String {
        switch self {
        case .all: "house"
        case .transactions: "list.bullet"
        case .accounts: "building.columns"
        case .categories: "square.grid.2x2"
        }
    }

    /// Analytics / breadcrumb name.
    var eventName: String { rawValue }
}
