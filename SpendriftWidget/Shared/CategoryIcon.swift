//
//  CategoryIcon.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//
//  Mirrors Spendrift/Models/Enums/CategoryIcon.swift — the widget reads the same
//  SwiftData store, so every case must exist here too or categories fail to decode.
//

import Foundation

enum CategoryIcon: String, Codable, CaseIterable {
    // Money
    case salary, freelance, bonus, dividend, investments, stocks, crypto
    case savings, wallet, interest, refunds, cashback, retirement
    case property, loan, creditCard, transfer, fees, tax
    // Food & drink
    case food, groceries, restaurant, coffee, fastFood, drinks
    case alcohol, dessert, snacks, produce
    // Shopping
    case shopping, clothing, accessories, jewelry, electronics
    case onlineShopping, coupons, sale
    // Home & bills
    case rent, home, mortgage, bills, electricity, water, gasUtility
    case internet, mobile, repairs, laundry, garbage, security, insurance
    // Transport
    case transportation, car, cab, fuel, evCharging, parking, tolls
    case carService, train, metro, bike, scooter
    // Travel
    case travel, hotel, luggage, tickets, vacation, camping, ferry, sightseeing
    // Health & personal
    case health, pharmacy, doctor, dental, eyecare, labTests, mentalHealth
    case gym, sport, yoga, beauty, haircut, spa, grooming
    // Entertainment
    case entertainment, movies, streaming, music, concerts, games, events
    case sportsEvents, nightlife, hobbies, photography, books, news, subscriptions
    // People & gifts
    case friends, family, baby, kids, toys, pets, wedding, celebration
    case gifts, charity
    // Education & work
    case education, tuition, courses, stationery, work, business
    case software, advertising, printing, legal
    // Other
    case emergency
    case miscellaneous
    case unknown
}

extension CategoryIcon {
    var systemImageName: String {
        switch self {
        // Money
        case .salary: return "briefcase"
        case .freelance: return "laptopcomputer"
        case .bonus: return "rosette"
        case .dividend: return "chart.line.uptrend.xyaxis"
        case .investments: return "chart.pie"
        case .stocks: return "chart.bar.xaxis"
        case .crypto: return "bitcoinsign.circle"
        case .savings: return "lock.circle"
        case .wallet: return "wallet.pass"
        case .interest: return "percent"
        case .refunds: return "arrow.uturn.backward"
        case .cashback: return "arrow.counterclockwise.circle"
        case .retirement: return "hourglass"
        case .property: return "building.2"
        case .loan: return "building.columns"
        case .creditCard: return "creditcard"
        case .transfer: return "arrow.left.arrow.right"
        case .fees: return "doc.plaintext"
        case .tax: return "doc.text.magnifyingglass"
        // Food & drink
        case .food: return "fork.knife"
        case .groceries: return "basket"
        case .restaurant: return "menucard"
        case .coffee: return "cup.and.saucer"
        case .fastFood: return "takeoutbag.and.cup.and.straw"
        case .drinks: return "mug"
        case .alcohol: return "wineglass"
        case .dessert: return "birthday.cake"
        case .snacks: return "popcorn"
        case .produce: return "carrot"
        // Shopping
        case .shopping: return "bag"
        case .clothing: return "tshirt"
        case .accessories: return "handbag"
        case .jewelry: return "diamond"
        case .electronics: return "iphone"
        case .onlineShopping: return "shippingbox"
        case .coupons: return "tag"
        case .sale: return "cart"
        // Home & bills
        case .rent: return "house.fill"
        case .home: return "house"
        case .mortgage: return "key"
        case .bills: return "doc.text"
        case .electricity: return "bolt"
        case .water: return "drop"
        case .gasUtility: return "flame"
        case .internet: return "wifi"
        case .mobile: return "antenna.radiowaves.left.and.right"
        case .repairs: return "hammer"
        case .laundry: return "washer"
        case .garbage: return "trash"
        case .security: return "lock.shield"
        case .insurance: return "shield"
        // Transport
        case .transportation: return "car"
        case .car: return "car.fill"
        case .cab: return "car.2"
        case .fuel: return "fuelpump"
        case .evCharging: return "bolt.car"
        case .parking: return "parkingsign.circle"
        case .tolls: return "road.lanes"
        case .carService: return "wrench.and.screwdriver"
        case .train: return "train.side.front.car"
        case .metro: return "tram"
        case .bike: return "bicycle"
        case .scooter: return "scooter"
        // Travel
        case .travel: return "airplane"
        case .hotel: return "bed.double"
        case .luggage: return "suitcase"
        case .tickets: return "ticket"
        case .vacation: return "beach.umbrella"
        case .camping: return "tent"
        case .ferry: return "ferry"
        case .sightseeing: return "map"
        // Health & personal
        case .health: return "cross.case"
        case .pharmacy: return "pills"
        case .doctor: return "stethoscope"
        case .dental: return "mouth"
        case .eyecare: return "eyeglasses"
        case .labTests: return "testtube.2"
        case .mentalHealth: return "brain.head.profile"
        case .gym: return "dumbbell"
        case .sport: return "figure.run"
        case .yoga: return "figure.yoga"
        case .beauty: return "sparkles"
        case .haircut: return "scissors"
        case .spa: return "leaf"
        case .grooming: return "comb"
        // Entertainment
        case .entertainment: return "tv"
        case .movies: return "film"
        case .streaming: return "play.rectangle"
        case .music: return "music.note"
        case .concerts: return "music.mic"
        case .games: return "gamecontroller"
        case .events: return "theatermasks"
        case .sportsEvents: return "sportscourt"
        case .nightlife: return "moon.stars"
        case .hobbies: return "paintbrush"
        case .photography: return "camera"
        case .books: return "books.vertical"
        case .news: return "newspaper"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        // People & gifts
        case .friends: return "person.2"
        case .family: return "person.3"
        case .baby: return "figure.child"
        case .kids: return "figure.and.child.holdinghands"
        case .toys: return "teddybear"
        case .pets: return "pawprint"
        case .wedding: return "heart"
        case .celebration: return "party.popper"
        case .gifts: return "gift"
        case .charity: return "hands.sparkles"
        // Education & work
        case .education: return "book"
        case .tuition: return "graduationcap"
        case .courses: return "text.book.closed"
        case .stationery: return "pencil"
        case .work: return "briefcase.fill"
        case .business: return "building"
        case .software: return "desktopcomputer"
        case .advertising: return "megaphone"
        case .printing: return "printer"
        case .legal: return "checkmark.seal"
        // Other
        case .emergency: return "exclamationmark.triangle"
        case .miscellaneous: return "questionmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
