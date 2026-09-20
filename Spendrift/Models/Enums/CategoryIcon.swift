//
//  CategoryIcon.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
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
    /// Filled SF Symbol variants read best inside the circular category tiles.
    var systemImageName: String {
        switch self {
        // Money
        case .salary: return "banknote.fill"
        case .freelance: return "laptopcomputer"
        case .bonus: return "rosette"
        case .dividend: return "chart.line.uptrend.xyaxis"
        case .investments: return "chart.pie.fill"
        case .stocks: return "chart.bar.xaxis"
        case .crypto: return "bitcoinsign.circle.fill"
        case .savings: return "lock.circle.fill"
        case .wallet: return "wallet.pass.fill"
        case .interest: return "percent"
        case .refunds: return "arrow.uturn.backward"
        case .cashback: return "arrow.counterclockwise.circle.fill"
        case .retirement: return "hourglass"
        case .property: return "building.2.fill"
        case .loan: return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        case .transfer: return "arrow.left.arrow.right"
        case .fees: return "doc.plaintext.fill"
        case .tax: return "doc.text.magnifyingglass"
        // Food & drink
        case .food: return "fork.knife"
        case .groceries: return "basket.fill"
        case .restaurant: return "menucard.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .fastFood: return "takeoutbag.and.cup.and.straw.fill"
        case .drinks: return "mug.fill"
        case .alcohol: return "wineglass.fill"
        case .dessert: return "birthday.cake.fill"
        case .snacks: return "popcorn.fill"
        case .produce: return "carrot.fill"
        // Shopping
        case .shopping: return "bag.fill"
        case .clothing: return "tshirt.fill"
        case .accessories: return "handbag.fill"
        case .jewelry: return "diamond.fill"
        case .electronics: return "iphone"
        case .onlineShopping: return "shippingbox.fill"
        case .coupons: return "tag.fill"
        case .sale: return "cart.fill"
        // Home & bills
        case .rent: return "house.fill"
        case .home: return "sofa.fill"
        case .mortgage: return "key.fill"
        case .bills: return "doc.text.fill"
        case .electricity: return "bolt.fill"
        case .water: return "drop.fill"
        case .gasUtility: return "flame.fill"
        case .internet: return "wifi"
        case .mobile: return "antenna.radiowaves.left.and.right"
        case .repairs: return "hammer.fill"
        case .laundry: return "washer.fill"
        case .garbage: return "trash.fill"
        case .security: return "lock.shield.fill"
        case .insurance: return "shield.fill"
        // Transport
        case .transportation: return "bus.fill"
        case .car: return "car.fill"
        case .cab: return "car.2.fill"
        case .fuel: return "fuelpump.fill"
        case .evCharging: return "bolt.car.fill"
        case .parking: return "parkingsign.circle.fill"
        case .tolls: return "road.lanes"
        case .carService: return "wrench.and.screwdriver.fill"
        case .train: return "train.side.front.car"
        case .metro: return "tram.fill"
        case .bike: return "bicycle"
        case .scooter: return "scooter"
        // Travel
        case .travel: return "airplane"
        case .hotel: return "bed.double.fill"
        case .luggage: return "suitcase.fill"
        case .tickets: return "ticket.fill"
        case .vacation: return "beach.umbrella.fill"
        case .camping: return "tent.fill"
        case .ferry: return "ferry.fill"
        case .sightseeing: return "map.fill"
        // Health & personal
        case .health: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .doctor: return "stethoscope"
        case .dental: return "mouth.fill"
        case .eyecare: return "eyeglasses"
        case .labTests: return "testtube.2"
        case .mentalHealth: return "brain.head.profile"
        case .gym: return "dumbbell.fill"
        case .sport: return "figure.run"
        case .yoga: return "figure.yoga"
        case .beauty: return "sparkles"
        case .haircut: return "scissors"
        case .spa: return "leaf.fill"
        case .grooming: return "comb.fill"
        // Entertainment
        case .entertainment: return "tv.fill"
        case .movies: return "film.fill"
        case .streaming: return "play.rectangle.fill"
        case .music: return "music.note"
        case .concerts: return "music.mic"
        case .games: return "gamecontroller.fill"
        case .events: return "theatermasks.fill"
        case .sportsEvents: return "sportscourt.fill"
        case .nightlife: return "moon.stars.fill"
        case .hobbies: return "paintbrush.fill"
        case .photography: return "camera.fill"
        case .books: return "books.vertical.fill"
        case .news: return "newspaper.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        // People & gifts
        case .friends: return "person.2.fill"
        case .family: return "person.3.fill"
        case .baby: return "figure.child"
        case .kids: return "figure.and.child.holdinghands"
        case .toys: return "teddybear.fill"
        case .pets: return "pawprint.fill"
        case .wedding: return "heart.fill"
        case .celebration: return "party.popper.fill"
        case .gifts: return "gift.fill"
        case .charity: return "hands.sparkles.fill"
        // Education & work
        case .education: return "book.fill"
        case .tuition: return "graduationcap.fill"
        case .courses: return "text.book.closed.fill"
        case .stationery: return "pencil"
        case .work: return "briefcase.fill"
        case .business: return "building.fill"
        case .software: return "desktopcomputer"
        case .advertising: return "megaphone.fill"
        case .printing: return "printer.fill"
        case .legal: return "checkmark.seal.fill"
        // Other
        case .emergency: return "exclamationmark.triangle.fill"
        case .miscellaneous: return "questionmark"
        case .unknown: return "questionmark"
        }
    }

    /// Short label shown under featured icons in the category editor.
    var pickerLabel: String {
        switch self {
        // Money
        case .salary: return "Salary"
        case .freelance: return "Freelance"
        case .bonus: return "Bonus"
        case .dividend: return "Dividend"
        case .investments: return "Invest"
        case .stocks: return "Stocks"
        case .crypto: return "Crypto"
        case .savings: return "Savings"
        case .wallet: return "Wallet"
        case .interest: return "Interest"
        case .refunds: return "Refund"
        case .cashback: return "Cashback"
        case .retirement: return "Pension"
        case .property: return "Property"
        case .loan: return "Loan"
        case .creditCard: return "Card"
        case .transfer: return "Transfer"
        case .fees: return "Fees"
        case .tax: return "Tax"
        // Food & drink
        case .food: return "Dining"
        case .groceries: return "Groceries"
        case .restaurant: return "Restaurant"
        case .coffee: return "Coffee"
        case .fastFood: return "Takeout"
        case .drinks: return "Drinks"
        case .alcohol: return "Alcohol"
        case .dessert: return "Dessert"
        case .snacks: return "Snacks"
        case .produce: return "Produce"
        // Shopping
        case .shopping: return "Shopping"
        case .clothing: return "Clothes"
        case .accessories: return "Bags"
        case .jewelry: return "Jewellery"
        case .electronics: return "Gadgets"
        case .onlineShopping: return "Orders"
        case .coupons: return "Coupon"
        case .sale: return "Cart"
        // Home & bills
        case .rent: return "Rent"
        case .home: return "Furniture"
        case .mortgage: return "Mortgage"
        case .bills: return "Bills"
        case .electricity: return "Power"
        case .water: return "Water"
        case .gasUtility: return "Gas"
        case .internet: return "Internet"
        case .mobile: return "Mobile"
        case .repairs: return "Repairs"
        case .laundry: return "Laundry"
        case .garbage: return "Waste"
        case .security: return "Security"
        case .insurance: return "Insurance"
        // Transport
        case .transportation: return "Transit"
        case .car: return "Car"
        case .cab: return "Cab"
        case .fuel: return "Fuel"
        case .evCharging: return "Charging"
        case .parking: return "Parking"
        case .tolls: return "Tolls"
        case .carService: return "Service"
        case .train: return "Train"
        case .metro: return "Metro"
        case .bike: return "Bike"
        case .scooter: return "Scooter"
        // Travel
        case .travel: return "Flights"
        case .hotel: return "Hotel"
        case .luggage: return "Luggage"
        case .tickets: return "Tickets"
        case .vacation: return "Holiday"
        case .camping: return "Camping"
        case .ferry: return "Ferry"
        case .sightseeing: return "Sightseeing"
        // Health & personal
        case .health: return "Health"
        case .pharmacy: return "Pharmacy"
        case .doctor: return "Doctor"
        case .dental: return "Dental"
        case .eyecare: return "Eyewear"
        case .labTests: return "Lab"
        case .mentalHealth: return "Mind"
        case .gym: return "Gym"
        case .sport: return "Fitness"
        case .yoga: return "Yoga"
        case .beauty: return "Beauty"
        case .haircut: return "Salon"
        case .spa: return "Spa"
        case .grooming: return "Grooming"
        // Entertainment
        case .entertainment: return "TV"
        case .movies: return "Movies"
        case .streaming: return "Streaming"
        case .music: return "Music"
        case .concerts: return "Concert"
        case .games: return "Games"
        case .events: return "Events"
        case .sportsEvents: return "Sports"
        case .nightlife: return "Nightlife"
        case .hobbies: return "Hobby"
        case .photography: return "Photo"
        case .books: return "Books"
        case .news: return "News"
        case .subscriptions: return "Subscribe"
        // People & gifts
        case .friends: return "Friends"
        case .family: return "Family"
        case .baby: return "Baby"
        case .kids: return "Kids"
        case .toys: return "Toys"
        case .pets: return "Pets"
        case .wedding: return "Wedding"
        case .celebration: return "Party"
        case .gifts: return "Gifts"
        case .charity: return "Charity"
        // Education & work
        case .education: return "School"
        case .tuition: return "College"
        case .courses: return "Course"
        case .stationery: return "Stationery"
        case .work: return "Work"
        case .business: return "Business"
        case .software: return "Software"
        case .advertising: return "Ads"
        case .printing: return "Printing"
        case .legal: return "Legal"
        // Other
        case .emergency: return "Emergency"
        case .miscellaneous, .unknown: return "Other"
        }
    }

    var pickerGroup: String {
        switch self {
        case .salary, .freelance, .bonus, .dividend, .investments, .stocks, .crypto,
             .savings, .wallet, .interest, .refunds, .cashback, .retirement,
             .property, .loan, .creditCard, .transfer, .fees, .tax:
            return "Money"
        case .food, .groceries, .restaurant, .coffee, .fastFood, .drinks,
             .alcohol, .dessert, .snacks, .produce:
            return "Food & drink"
        case .shopping, .clothing, .accessories, .jewelry, .electronics,
             .onlineShopping, .coupons, .sale:
            return "Shopping"
        case .rent, .home, .mortgage, .bills, .electricity, .water, .gasUtility,
             .internet, .mobile, .repairs, .laundry, .garbage, .security, .insurance:
            return "Home & bills"
        case .transportation, .car, .cab, .fuel, .evCharging, .parking, .tolls,
             .carService, .train, .metro, .bike, .scooter:
            return "Transport"
        case .travel, .hotel, .luggage, .tickets, .vacation, .camping, .ferry, .sightseeing:
            return "Travel"
        case .health, .pharmacy, .doctor, .dental, .eyecare, .labTests, .mentalHealth,
             .gym, .sport, .yoga, .beauty, .haircut, .spa, .grooming:
            return "Health & personal"
        case .entertainment, .movies, .streaming, .music, .concerts, .games, .events,
             .sportsEvents, .nightlife, .hobbies, .photography, .books, .news, .subscriptions:
            return "Entertainment"
        case .friends, .family, .baby, .kids, .toys, .pets, .wedding, .celebration,
             .gifts, .charity:
            return "People & gifts"
        case .education, .tuition, .courses, .stationery, .work, .business,
             .software, .advertising, .printing, .legal:
            return "Education & work"
        case .emergency, .miscellaneous, .unknown:
            return "Other"
        }
    }

    var searchKeywords: String {
        switch self {
        // Money
        case .salary: return "salary income wage paycheck payday"
        case .freelance: return "freelance side gig contract client consulting"
        case .bonus: return "bonus incentive reward commission appraisal"
        case .dividend: return "dividend payout growth chart"
        case .investments: return "investments mutual fund sip portfolio finance"
        case .stocks: return "stocks shares equity trading market"
        case .crypto: return "crypto bitcoin coin wallet blockchain"
        case .savings: return "savings save deposit emergency fund fd"
        case .wallet: return "wallet cash pocket money upi balance"
        case .interest: return "interest yield returns percent"
        case .refunds: return "refund return reimbursement"
        case .cashback: return "cashback reward points rebate"
        case .retirement: return "retirement pension provident nps"
        case .property: return "property real estate rental income land"
        case .loan: return "loan emi borrow repayment bank debt"
        case .creditCard: return "credit card debit bill payment"
        case .transfer: return "transfer send money payment upi"
        case .fees: return "fees charges service charge penalty"
        case .tax: return "tax document filing gst tds"
        // Food & drink
        case .food: return "food dining eat lunch dinner meal"
        case .groceries: return "groceries grocery supermarket basket vegetables"
        case .restaurant: return "restaurant dine out cafe menu eatery"
        case .coffee: return "coffee cafe tea espresso latte"
        case .fastFood: return "fast food takeaway takeout delivery burger swiggy zomato"
        case .drinks: return "drinks beverage juice soda tea beer"
        case .alcohol: return "alcohol wine liquor drinks bar pub"
        case .dessert: return "dessert cake sweets bakery ice cream"
        case .snacks: return "snacks munchies chips popcorn"
        case .produce: return "produce vegetables fruits veggies farm"
        // Shopping
        case .shopping: return "shopping bag purchase retail mall"
        case .clothing: return "clothing clothes shirt fashion apparel"
        case .accessories: return "accessories handbag purse belt watch"
        case .jewelry: return "jewellery jewelry gold diamond ornaments"
        case .electronics: return "electronics gadget phone laptop device"
        case .onlineShopping: return "online order parcel package delivery amazon flipkart"
        case .coupons: return "coupon tag sale discount offer voucher"
        case .sale: return "sale cart shopping purchase"
        // Home & bills
        case .rent: return "rent house home lease landlord"
        case .home: return "home furniture sofa interior decor"
        case .mortgage: return "mortgage home loan keys emi property"
        case .bills: return "bills invoice document utility payment"
        case .electricity: return "electricity power current light bill"
        case .water: return "water bill plumbing tanker"
        case .gasUtility: return "gas lpg cylinder cooking fuel"
        case .internet: return "internet wifi broadband fiber router"
        case .mobile: return "mobile phone recharge data plan network"
        case .repairs: return "repairs maintenance handyman fixing carpenter"
        case .laundry: return "laundry washing dry clean ironing"
        case .garbage: return "garbage waste trash sanitation disposal"
        case .security: return "security guard alarm society cctv"
        case .insurance: return "insurance shield cover premium policy"
        // Transport
        case .transportation: return "transport commute bus public transit"
        case .car: return "car vehicle drive auto"
        case .cab: return "cab taxi uber ola ride share"
        case .fuel: return "fuel petrol diesel gas pump"
        case .evCharging: return "ev charging electric vehicle charger"
        case .parking: return "parking valet garage"
        case .tolls: return "toll fastag highway road"
        case .carService: return "service repair garage mechanic maintenance"
        case .train: return "train rail railway irctc"
        case .metro: return "metro tram subway local"
        case .bike: return "bike bicycle cycle cycling"
        case .scooter: return "scooter moped two wheeler motorcycle"
        // Travel
        case .travel: return "travel flight airplane airfare trip"
        case .hotel: return "hotel stay accommodation lodging room"
        case .luggage: return "luggage baggage suitcase packing"
        case .tickets: return "tickets booking pass reservation"
        case .vacation: return "holiday vacation beach resort getaway"
        case .camping: return "camping trek outdoors tent hiking"
        case .ferry: return "ferry boat cruise ship"
        case .sightseeing: return "sightseeing tour map attractions"
        // Health & personal
        case .health: return "health medical care hospital clinic"
        case .pharmacy: return "pharmacy medicine pills chemist prescription"
        case .doctor: return "doctor consultation checkup physician"
        case .dental: return "dental dentist teeth braces"
        case .eyecare: return "eye care optician glasses spectacles lens"
        case .labTests: return "lab test diagnostics blood scan report"
        case .mentalHealth: return "mental health therapy counselling wellbeing"
        case .gym: return "gym workout weights training membership"
        case .sport: return "sport fitness run jogging exercise"
        case .yoga: return "yoga pilates meditation stretching"
        case .beauty: return "beauty cosmetics makeup skincare"
        case .haircut: return "haircut salon barber styling"
        case .spa: return "spa massage relax wellness"
        case .grooming: return "grooming personal care toiletries hygiene"
        // Entertainment
        case .entertainment: return "entertainment tv shows leisure"
        case .movies: return "movies cinema film theatre"
        case .streaming: return "streaming netflix prime ott video"
        case .music: return "music songs spotify audio"
        case .concerts: return "concert gig live show band"
        case .games: return "games gaming console video game"
        case .events: return "events theatre comedy show play"
        case .sportsEvents: return "sports match stadium game tickets"
        case .nightlife: return "nightlife club party night out"
        case .hobbies: return "hobby craft painting art diy"
        case .photography: return "photography camera photos lens"
        case .books: return "books reading novels library kindle"
        case .news: return "news newspaper magazine subscription"
        case .subscriptions: return "subscription recurring membership renewal plan"
        // People & gifts
        case .friends: return "friends people shared split"
        case .family: return "family household parents relatives"
        case .baby: return "baby infant diapers newborn"
        case .kids: return "kids children childcare school run"
        case .toys: return "toys games playtime kids"
        case .pets: return "pets dog cat vet pet food"
        case .wedding: return "wedding marriage anniversary engagement"
        case .celebration: return "party celebration birthday festival"
        case .gifts: return "gifts present giving birthday"
        case .charity: return "charity donation ngo giving zakat tithe"
        // Education & work
        case .education: return "education school books study fees"
        case .tuition: return "college university tuition degree admission"
        case .courses: return "course online class training certification"
        case .stationery: return "stationery pens notebooks supplies"
        case .work: return "work office job business expense"
        case .business: return "business company startup office rent"
        case .software: return "software saas apps tools licence subscription"
        case .advertising: return "advertising ads marketing promotion"
        case .printing: return "printing print xerox stationery"
        case .legal: return "legal lawyer notary compliance registration"
        // Other
        case .emergency: return "emergency urgent unexpected contingency"
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
