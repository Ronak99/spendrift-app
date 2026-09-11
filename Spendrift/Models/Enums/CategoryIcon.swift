//
//  CategoryIcon.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

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

    /// Short label shown under featured icons in the category editor.
    var pickerLabel: String {
        switch self {
        case .dividend: return "Chart"
        case .friends: return "Family"
        case .salary: return "Salary"
        case .coupons: return "Tag"
        case .refunds: return "Refund"
        case .sale: return "Cart"
        case .bills: return "Bills"
        case .education: return "School"
        case .entertainment: return "TV"
        case .food: return "Dining"
        case .health: return "Health"
        case .home: return "Furniture"
        case .investments: return "Invest"
        case .shopping: return "Bag"
        case .sport: return "Fitness"
        case .transportation: return "Transit"
        case .baby: return "Baby"
        case .beauty: return "Beauty"
        case .clothing: return "Clothes"
        case .tax: return "Tax"
        case .electronics: return "Gadgets"
        case .insurance: return "Cover"
        case .groceries: return "Basket"
        case .rent: return "Home"
        case .miscellaneous, .unknown: return "Other"
        }
    }

    var pickerGroup: String {
        switch self {
        case .shopping, .clothing, .electronics, .coupons, .sale:
            return "Shopping"
        case .food, .groceries:
            return "Food & drink"
        case .home, .bills, .rent, .insurance, .tax:
            return "Home & bills"
        case .transportation:
            return "Transport"
        case .health, .beauty, .baby, .sport:
            return "Health & personal"
        case .salary, .dividend, .investments, .refunds, .friends, .education:
            return "Money"
        case .entertainment, .miscellaneous, .unknown:
            return "Other"
        }
    }

    var searchKeywords: String {
        switch self {
        case .dividend: return "dividend invest growth chart"
        case .friends: return "friends family people shared"
        case .salary: return "salary income wage paycheck"
        case .coupons: return "coupon tag sale discount"
        case .refunds: return "refund return cashback"
        case .sale: return "sale cart shopping purchase"
        case .bills: return "bills invoice document utility"
        case .education: return "education school books study fees"
        case .entertainment: return "entertainment tv movie streaming"
        case .food: return "food dining restaurant eat lunch"
        case .health: return "health medical care hospital"
        case .home: return "home furniture sofa house"
        case .investments: return "investments pie finance"
        case .shopping: return "shopping bag purchase"
        case .sport: return "sport gym fitness run workout"
        case .transportation: return "transport car commute travel"
        case .baby: return "baby child kids"
        case .beauty: return "beauty salon sparkle"
        case .clothing: return "clothing clothes shirt fashion"
        case .tax: return "tax document filing"
        case .electronics: return "electronics gadget phone"
        case .insurance: return "insurance shield cover"
        case .groceries: return "groceries grocery supermarket basket"
        case .rent: return "rent house mortgage home"
        case .miscellaneous, .unknown: return "other misc miscellaneous"
        }
    }

    static var selectable: [CategoryIcon] {
        allCases.filter { $0 != .unknown }
    }

    static let featuredForPicker: [CategoryIcon] = [
        .shopping, .groceries, .food, .rent, .transportation, .health, .salary, .bills
    ]

    static var pickerGroups: [(title: String, icons: [CategoryIcon])] {
        var grouped: [(String, [CategoryIcon])] = []
        for icon in selectable {
            if let index = grouped.firstIndex(where: { $0.0 == icon.pickerGroup }) {
                grouped[index].1.append(icon)
            } else {
                grouped.append((icon.pickerGroup, [icon]))
            }
        }
        return grouped.map { (title: $0.0, icons: $0.1) }
    }
}
