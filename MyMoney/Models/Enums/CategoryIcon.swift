//
//  CategoryIcon.swift
//  MyMoney
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
    case unknown
}
