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
    var isSelected: Bool = false

    private let enamelSize: CGFloat = 80

    private var enamelColor: Color {
        CategoryEnamel.color(for: category)
    }

    var body: some View {
        VStack(spacing: 10) {
            CategoryEnamelTile(
                systemImage: category.icon.systemImageName,
                color: enamelColor
            )
            .frame(width: enamelSize, height: enamelSize)
            .overlay {
                RoundedRectangle(cornerRadius: enamelSize * 0.33 + 4, style: .continuous)
                    .strokeBorder(enamelColor, lineWidth: 2)
                    .padding(-4)
                    .opacity(isSelected ? 1 : 0)
            }

            Text(category.name)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
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
    static let uncategorized = Color(hex: "#8E9AA8")
    static let income = Color(hex: CategoryPalette.defaultIncomeHex)
    static let expense = Color(hex: "#FF6B6B")

    static func color(for category: TransactionCategory?) -> Color {
        guard let category else { return uncategorized }
        if let hex = CategoryPalette.normalizedHex(category.colorHex) {
            return Color(hex: hex)
        }
        let name = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return Color(hex: CategoryPalette.defaultHex(for: category.type))
        }
        return Color(hex: CategoryPalette.hex(matching: ColoredCategories.swatch(forName: name)))
    }

    /// Wash on the Categories tab: first chip in the visible type, else that type's default.
    static func atmosphere(in categories: [TransactionCategory], type: CategoryType) -> Color {
        let visible = categories
            .filter { $0.type == type }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        if let first = visible.first {
            return color(for: first)
        }
        return Color(hex: CategoryPalette.defaultHex(for: type))
    }
}

/// Glossy rounded tile: solid colour, top-leading sheen, white hairline, ink icon.
struct CategoryEnamelTile: View {
    let systemImage: String
    let color: Color
    var showsShadow: Bool = true

    private var motionToken: String {
        "\(systemImage)-\(AppMotion.colorToken(color))"
    }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let radius = side * 0.33
                    let iconSize = max(14, side * 0.38)

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
                            .shadow(
                                color: showsShadow ? color.opacity(0.32) : .clear,
                                radius: showsShadow ? side * 0.12 : 0,
                                y: showsShadow ? side * 0.08 : 0
                            )

                        Image(systemName: systemImage)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(Color(hex: "#0A0A0B"))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .frame(width: side, height: side)
                }
            }
            .washMotion(value: motionToken)
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
