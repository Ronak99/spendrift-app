//
//  CategoryGridItem.swift
//  Spendrift
//
//  Enamel chip for the Categories tray: the same glossy squircle, highlight,
//  hairline, and ink glyph used by the category editor.
//

import SwiftUI

struct CategoryGridItem: View {
    let category: TransactionCategory

    private let enamelSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 10) {
            CategoryEnamelTile(
                systemImage: category.icon.systemImageName,
                color: CategoryEnamel.color(for: category)
            )
            .frame(width: enamelSize, height: enamelSize)

            Text(category.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(height: 30, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Palette fill for a category chip. Explicit `colorHex` wins; otherwise the
/// editor's curated swatch for the name, so the tray always matches the sheet.
enum CategoryEnamel {
    static func color(for category: TransactionCategory) -> Color {
        if let hex = CategoryPalette.normalizedHex(category.colorHex) {
            return Color(hex: hex)
        }
        let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return Color(hex: CategoryPalette.defaultHex(for: category.type))
        }
        return Color(hex: CategoryPalette.hex(matching: ColoredCategories.swatch(forName: name)))
    }
}

/// Glossy rounded tile: solid colour, top-leading sheen, white hairline, ink icon.
struct CategoryEnamelTile: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let radius = side * 0.33
                    let iconSize = max(18, side * 0.38)

                    ZStack {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(color)
                            .overlay {
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.35), .clear],
                                            startPoint: .topLeading,
                                            endPoint: UnitPoint(x: 0.55, y: 0.7)
                                        )
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
                            }
                            .shadow(color: color.opacity(0.32), radius: side * 0.12, y: side * 0.08)

                        Image(systemName: systemImage)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(Color(hex: "#0A0A0B"))
                    }
                    .frame(width: side, height: side)
                }
            }
            .accessibilityHidden(true)
    }
}

struct CategoryTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.72),
                value: configuration.isPressed
            )
    }
}

#Preview {
    HStack(alignment: .top, spacing: 16) {
        CategoryGridItem(category: TransactionCategory(name: "Food", type: .expense, icon: .food, colorHex: "#FF6B6B"))
        CategoryGridItem(category: TransactionCategory(name: "Bills & Utilities", type: .expense, icon: .bills, colorHex: "#FFC94D"))
        CategoryGridItem(category: TransactionCategory(name: "Salary", type: .income, icon: .salary, colorHex: "#4FC3A1"))
    }
    .padding()
    .background(AppTheme.listBackground)
}
