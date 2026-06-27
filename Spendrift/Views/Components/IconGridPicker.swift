//
//  IconGridPicker.swift
//  Spendrift
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
        if let categoryIcon = icon as? CategoryIcon {
            return categoryIcon.systemImageName
        }

        let rawValue = icon.rawValue.lowercased()
        switch rawValue {
        case "bankaccountone":
            return "building.2"
        case "bankaccounttwo":
            return "bolt.circle"
        case "bankaccountthree":
            return "indianrupeesign.circle"
        case "bankaccountfour":
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
