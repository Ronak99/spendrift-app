//
//  StatRow.swift
//  MyMoney
//
//  Created by Ronak Punase on 03/08/25.
//


import SwiftUI
import PDFKit
import Foundation

struct StatRow: View {
    let title: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}