//
//  CategoryIcon.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

enum CategoryIcon: String, Codable, CaseIterable {
    case dividend, friends, salary, coupons, refunds, sale
    case bills, education, entertainment, food, health, home
    case investments, shopping, sport, transportation, baby
    case beauty, clothing, tax, electronics, insurance
    case groceries, rent
    case miscellaneous
    case unknown
}

extension CategoryIcon {
    var systemImageName: String {
        switch self {
        case .dividend: return "chart.line.uptrend.xyaxis"
        case .friends: return "person.2"
        case .salary: return "briefcase"
        case .coupons: return "tag"
        case .refunds: return "arrow.uturn.backward"
        case .sale: return "cart"
        case .bills: return "doc.text"
        case .education: return "book"
        case .entertainment: return "tv"
        case .food: return "fork.knife"
        case .health: return "cross.case"
        case .home: return "house"
        case .investments: return "chart.pie"
        case .shopping: return "bag"
        case .sport: return "figure.run"
        case .transportation: return "car"
        case .baby: return "figure.child"
        case .beauty: return "sparkles"
        case .clothing: return "tshirt"
        case .tax: return "doc.text.magnifyingglass"
        case .electronics: return "iphone"
        case .insurance: return "shield"
        case .groceries: return "basket"
        case .rent: return "house.fill"
        case .miscellaneous: return "questionmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
