//
//  HomeTab.swift
//  Spendrift
//
//  The four tabs in the tab bar. Raw values double as the `TabView` selection,
//  and the title bar of each tab reads its title at the leading edge.
//

import Foundation

enum HomeTab: Int, CaseIterable, Identifiable {
    case transactions = 0
    case accounts
    case categories
    case analytics

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .transactions: "Transactions"
        case .accounts: "Accounts"
        case .categories: "Categories"
        case .analytics: "Analytics"
        }
    }

    /// Tab bar glyph.
    var symbol: String {
        switch self {
        case .transactions: "house.fill"
        case .accounts: "building.columns.fill"
        case .categories: "square.grid.2x2.fill"
        case .analytics: "chart.xyaxis.line"
        }
    }

    /// Analytics / breadcrumb name.
    var eventName: String {
        switch self {
        case .transactions: "transactions"
        case .accounts: "accounts"
        case .categories: "categories"
        case .analytics: "analytics"
        }
    }
}
