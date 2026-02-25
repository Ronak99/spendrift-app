//
//  CapsuleDateSelector.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct CapsuleDateSelector: View {
    let date: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(date.monthYear)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    CapsuleDateSelector(
        date: Date(),
        onPrevious: {},
        onNext: {}
    )
    .padding()
}
