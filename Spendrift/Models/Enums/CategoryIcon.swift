//
//  CategoryIcon.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

enum CategoryIcon: String, Codable, CaseIterable {
    // Income
    case dividend, friends, salary, coupons, refunds, sale
    // Expense
    case bills, education, entertainment, food, health, home
    case investments, shopping, sport, transportation, baby
    case beauty, clothing, tax, electronics, insurance
    case groceries, rent
    case miscellaneous
    case unknown
}

extension CategoryIcon {
    /// Filled SF Symbol variants read best inside the circular category tiles.
    var systemImageName: String {
        switch self {
        case .dividend: return "chart.line.uptrend.xyaxis"
        case .friends: return "person.2.fill"
        case .salary: return "banknote.fill"
        case .coupons: return "tag.fill"
        case .refunds: return "arrow.uturn.backward"
        case .sale: return "cart.fill"
        case .bills: return "doc.text.fill"
        case .education: return "book.fill"
        case .entertainment: return "tv.fill"
        case .food: return "fork.knife"
        case .health: return "cross.case.fill"
        case .home: return "sofa.fill"
        case .investments: return "chart.pie.fill"
        case .shopping: return "bag.fill"
        case .sport: return "figure.run"
        case .transportation: return "bus.fill"
        case .baby: return "figure.child"
        case .beauty: return "sparkles"
        case .clothing: return "tshirt.fill"
        case .tax: return "doc.text.magnifyingglass"
        case .electronics: return "iphone"
        case .insurance: return "shield.fill"
        case .groceries: return "basket.fill"
        case .rent: return "house.fill"
        case .unknown: return "questionmark"
        case .miscellaneous: return "questionmark"
        }
    }

    /// Color group for the icon. Related categories share a hue so the grid reads as a system:
    /// food in orange, groceries in green, transport in indigo, housing and bills in blue/teal,
    /// shopping in pink, health in red, income in teal/cyan, everything else in gray.
    var tint: Color {
        switch self {
        case .food: return .orange
        case .groceries: return .green
        case .transportation: return .indigo
        case .bills, .insurance: return .blue
        case .rent, .home: return .teal
        case .shopping, .clothing, .beauty, .baby: return .pink
        case .electronics: return .purple
        case .health: return .red
        case .sport: return .mint
        case .entertainment: return .purple
        case .education: return .yellow
        case .investments, .dividend: return .cyan
        case .tax: return .brown
        case .salary, .sale, .coupons, .refunds, .friends: return .teal
        case .miscellaneous, .unknown: return .gray
        }
    }
}
