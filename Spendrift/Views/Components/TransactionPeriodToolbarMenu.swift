//
//  TransactionPeriodToolbarMenu.swift
//  Spendrift
//

import SwiftUI

struct TransactionPeriodToolbarMenu: View {
    @Binding var period: TransactionPeriod

    var body: some View {
        Menu {
            ForEach(TransactionPeriod.allCases) { p in
                Button {
                    period = p
                } label: {
                    HStack {
                        Text(p.label)
                        Spacer(minLength: 12)
                        if period == p {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Time range")
    }
}
