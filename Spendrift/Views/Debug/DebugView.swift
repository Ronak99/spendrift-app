//
//  DebugView.swift
//  Spendrift
//
//  Created by Ronak Punase on 03/08/25.
//


import SwiftUI
import PDFKit
import Foundation

struct DebugView: View {
    let text: String
    
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}