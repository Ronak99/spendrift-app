//
//  CategoryListItem.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct CategoryListItem: View {
    let category: TransactionCategory
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: categoryIconName)
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
            
            // Category name
            Text(category.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var categoryIconName: String {
        switch category.icon {
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
        case .unknown: return "circle"
        }
    }
}

#Preview {
    List {
        CategoryListItem(category: TransactionCategory(
            name: "Food",
            type: .expense,
            icon: .food
        ))
    }
}
