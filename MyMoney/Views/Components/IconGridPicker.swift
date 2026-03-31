//
//  IconGridPicker.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct IconGridPicker<T: RawRepresentable & CaseIterable & Hashable>: View where T.RawValue == String {
    let icons: [T]
    @Binding var selectedIcon: T
    let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(icons), id: \.self) { icon in
                Button(action: {
                    selectedIcon = icon
                    print("An icon was selected: \(icon), \(selectedIcon)")
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                selectedIcon == icon ? Color.accentColor
                                    .opacity(0.2) : Color(.systemGray6)
                            )
                            .frame(width: 60, height: 60)
                            
                        Image(systemName: iconName(for: icon))
                            .font(.title2)
                            .foregroundColor(
                                selectedIcon == icon ? .accentColor : .primary
                            )
                            
                        if selectedIcon == icon {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .offset(x: 20, y: -20)
                        }
                    }
                }
            }
        }
        .buttonStyle(.borderless)
        .padding()
    }
    
    private func iconName(for icon: T) -> String {
        let rawValue = icon.rawValue.lowercased()
        // Map icon names to SF Symbols
        switch rawValue {
        case "sbi":
            return "building.2"
        case "fi":
            return "bolt.circle"
        case "icici":
            return "indianrupeesign.circle"
        case "hdfc":
            return "building.columns"
        case "mastercard":
            return "creditcard"
        case "visa":
            return "creditcard.fill"
        case "cash":
            return "banknote"
        case "wallet":
            return "wallet.pass"
        case "savings":
            return "lock.circle"
        case "unknown":
            return "questionmark.circle"
        case "dividend":
            return "chart.line.uptrend.xyaxis"
        case "friends":
            return "person.2"
        case "salary":
            return "briefcase"
        case "coupons":
            return "tag"
        case "refunds":
            return "arrow.uturn.backward"
        case "sale":
            return "cart"
        case "bills":
            return "doc.text"
        case "education":
            return "book"
        case "entertainment":
            return "tv"
        case "food":
            return "fork.knife"
        case "health":
            return "cross.case"
        case "home":
            return "house"
        case "investments":
            return "chart.pie"
        case "shopping":
            return "bag"
        case "sport":
            return "figure.run"
        case "transportation":
            return "car"
        case "baby":
            return "figure.child"
        case "beauty":
            return "sparkles"
        case "clothing":
            return "tshirt"
        case "tax":
            return "doc.text.magnifyingglass"
        case "electronics":
            return "iphone"
        case "insurance":
            return "shield"
        default:
            return "xmark"
        }
    }
}

#Preview {
    @Previewable @State var selectedIcon = AccountIcon.bankAccountOne
    
    return IconGridPicker(
        icons: Array(AccountIcon.allCases),
        selectedIcon: $selectedIcon
    )
}
