//
//  CategoryType.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import Foundation

enum CategoryType: String, Codable, CaseIterable {
    case expense
    case income
}

extension CategoryType {
    var displayName: String { rawValue.capitalized }

    /// Second line in the type pickers.
    var menuSubtitle: String {
        switch self {
        case .expense: return "Money going out"
        case .income: return "Money coming in"
        }
    }

    /// Direction glyph: out of the account, or into it.
    var flowSymbolName: String {
        switch self {
        case .expense: return "arrow.up.right"
        case .income: return "arrow.down.left"
        }
    }
}
