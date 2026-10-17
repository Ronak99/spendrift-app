//
//  HomeComponents.swift
//  Spendrift
//
//  The pieces every Home block is made of: the card surface, the section
//  header, hairline-separated rows, stat tiles and budget bars.
//

import SwiftUI

/// Raised surface behind a Home block. Rows inside separate themselves with hairlines.
struct HomeCard<Content: View>: View {
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 6
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Uppercase block title. Tappable, with a chevron, when it leads somewhere.
struct HomeSectionHeader: View {
    let title: String
    var showsChevron: Bool = false
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .padding(.horizontal, 4)
    }

    private var label: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(AppTheme.inkSecondary)
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.inkTertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Hairline between rows inside a card.
struct HomeRowDivider: View {
    var body: some View {
        AppTheme.hairline
            .frame(height: 1)
    }
}

/// Trailing link inside a card: "All transactions", "Add a category budget".
struct HomeCardLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HomeRowDivider()
            Button(action: action) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.inkTertiary)
                }
                .padding(.top, 13)
                .padding(.bottom, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// A 3pt budget track: fill in the entity colour, red once the cap is passed.
struct BudgetBar: View {
    let spent: Double
    let cap: Double
    let color: Color
    var width: CGFloat?

    private var fraction: Double {
        guard cap > 0 else { return 0 }
        return min(1, max(0, spent / cap))
    }

    private var isOver: Bool { cap > 0 && spent > cap }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(AppTheme.ink.opacity(0.1))
                Capsule(style: .continuous)
                    .fill(isOver ? AppTheme.expense : color)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(width: width, height: 3)
        .accessibilityHidden(true)
    }
}

/// One of the four numbers that answer "am I okay this month?".
struct HomeStatTile: View {
    let caption: String
    let value: String
    var valueSuffix: String?
    let detail: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.inkSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.4)
                    .monospacedDigit()
                if let valueSuffix {
                    Text(valueSuffix)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            detail
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.inkTertiary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Enamel chip at an explicit size, for rows and badges that are not list items.
struct EnamelBadge: View {
    let systemImage: String
    let color: Color
    var side: CGFloat = 36
    var showsShadow: Bool = false

    var body: some View {
        CategoryEnamelTile(systemImage: systemImage, color: color, showsShadow: showsShadow)
            .frame(width: side, height: side)
    }
}

/// Dashed slot that creates the thing its list holds. Sits first so a long list
/// never hides it, and never reads as another way to add a transaction.
struct CreateSlotEnamel: View {
    var side: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: side * 0.33, style: .continuous)
            .strokeBorder(
                AppTheme.inkTertiary,
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
            )
            .frame(width: side, height: side)
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: side * 0.4, weight: .semibold))
                    .foregroundStyle(AppTheme.inkSecondary)
            }
            .accessibilityHidden(true)
    }
}

/// Press feedback for the whole-card buttons on Home.
struct HomePressStyle: ButtonStyle {
    var scale: CGFloat = 0.99

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension View {
    /// Room under a pane for the bottom tray, which floats over it.
    func homeTrayClearance() -> some View {
        contentMargins(.bottom, 140, for: .scrollContent)
    }
}
