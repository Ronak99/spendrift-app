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
                
                Image(systemName: category.icon.systemImageName)
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
