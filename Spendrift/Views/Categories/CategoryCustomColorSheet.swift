//
//  CategoryCustomColorSheet.swift
//  Spendrift
//
//  Shade grid of one hue so custom colours still sit with the editor palette.
//

import SwiftUI
import UIKit

struct CategoryCustomColorSheet: View {
    let initialHex: String
    var onUse: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var hue: Double
    @State private var selectedRow: Int
    @State private var selectedColumn: Int

    private let saturations: [Double] = [0.28, 0.42, 0.55, 0.68, 0.80, 0.90]
    private let brightnesses: [Double] = [0.88, 0.72, 0.56]

    init(initialHex: String, onUse: @escaping (String) -> Void) {
        self.initialHex = initialHex
        self.onUse = onUse
        let hsb = Self.hsb(from: initialHex)
        _hue = State(initialValue: hsb.hue)
        _selectedRow = State(initialValue: 1)
        _selectedColumn = State(initialValue: 3)
    }

    private var previewColor: Color {
        color(row: selectedRow, column: selectedColumn)
    }

    private var previewHex: String {
        previewColor.hexString ?? initialHex
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(previewColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: previewColor.opacity(0.35), radius: 12, y: 6)
                        .washMotion(value: "\(selectedRow)-\(selectedColumn)")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(previewHex)
                            .font(.system(size: 19, weight: .bold))
                            .tracking(-0.3)
                        Text("Tap a shade or drag the hue")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                hueSlider

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                    spacing: 10
                ) {
                    ForEach(0..<18, id: \.self) { index in
                        let row = index / 6
                        let column = index % 6
                        let isOn = row == selectedRow && column == selectedColumn
                        Button {
                            selectedRow = row
                            selectedColumn = column
                        } label: {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(color(row: row, column: column))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isOn ? Color.primary : Color.clear, lineWidth: 2.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Shade \(index + 1)")
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Custom Colour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                CustomSheetCloseToolbarItem()
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        onUse(previewHex)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(previewColor)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(colorScheme == .dark ? Color(hex: "#16161A") : AppTheme.listGroupBackground)
    }

    private var hueSlider: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0].map {
                                Color(hue: $0, saturation: 0.85, brightness: 0.95)
                            },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 14)

                Circle()
                    .fill(Color(hue: hue, saturation: 0.9, brightness: 0.95))
                    .overlay(Circle().strokeBorder(colorScheme == .dark ? Color(hex: "#16161A") : Color.white, lineWidth: 3))
                    .frame(width: 22, height: 22)
                    .offset(x: max(0, min(width - 22, CGFloat(hue) * (width - 22))))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    let t = value.location.x / max(width, 1)
                    hue = min(1, max(0, t))
                }
            )
        }
        .frame(height: 22)
        .accessibilityLabel("Hue")
    }

    private func color(row: Int, column: Int) -> Color {
        Color(
            hue: hue,
            saturation: saturations[column],
            brightness: brightnesses[row]
        )
    }

    private static func hsb(from hex: String) -> (hue: Double, saturation: Double, brightness: Double) {
        let color = UIColor(Color(hex: hex))
        var hue: CGFloat = 0.3
        var saturation: CGFloat = 0.6
        var brightness: CGFloat = 0.8
        var alpha: CGFloat = 1
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (Double(hue), Double(saturation), Double(brightness))
    }
}

#Preview {
    CategoryCustomColorSheet(initialHex: CategoryPalette.defaultExpenseHex) { _ in }
}
