//
//  SettingsView.swift
//  MyMoney
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("themeColor") private var themeColorName: String = "Blue"
    
    private let themeColors: [(name: String, color: Color)] = [
        ("Cyan", Color(hex: "#22D3EE")),
        ("Blue", Color(hex: "#3B82F6")),
        ("Purple", Color(hex: "#A78BFA")),
        ("Pink", Color(hex: "#EC4899")),
        ("Red", Color(hex: "#EF4444")),
        ("Orange", Color(hex: "#F59E0B")),
        ("Green", Color(hex: "#34D399")),
        ("Teal", Color(hex: "#14B8A6"))
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose a color to customize your app theme")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Theme Color")
                }
                
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(themeColors, id: \.name) { themeColor in
                            Button(action: {
                                themeColorName = themeColor.name
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(themeColor.color)
                                        .frame(width: 50, height: 50)
                                    
                                    if themeColorName == themeColor.name {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
