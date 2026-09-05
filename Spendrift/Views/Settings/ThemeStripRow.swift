//
//  ThemeStripRow.swift
//  Spendrift
//
//  Theme picker as a single settings row: the swatches live in a horizontal
//  scroller that starts tucked against the trailing edge and slides across the
//  "Theme" label as you drag it open.
//

import SwiftUI

struct ThemeStripRow: View {
    @Binding var selectedIndex: Int
    let accent: Color
    let accentSoft: Color

    private static let startAnchor = "theme-strip-start"
    /// How much of the strip peeks out on the trailing edge at rest.
    private static let restingPeek: CGFloat = 96
    private static let swatchDiameter: CGFloat = 18
    /// Swatch diameter plus the gap, so cells tile at the same pitch the design uses.
    private static let swatchCell: CGFloat = 28

    @State private var rowWidth: CGFloat = 0
    @State private var isScrolledOpen = false

    /// Selected colour leads, the rest keep their palette order behind it.
    private var orderedIndices: [Int] {
        let selected = Color.normalizedThemeIndex(selectedIndex)
        return [selected] + Color.themePalette.indices.filter { $0 != selected }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            label
            strip
        }
        .frame(height: SettingsTokens.rowHeight)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { rowWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in rowWidth = width }
            }
        }
    }

    private var label: some View {
        HStack(spacing: SettingsTokens.iconGap) {
            SettingsIconTile(systemName: "paintpalette.fill", accent: accent, accentSoft: accentSoft)
            Text("Theme")
                .font(.system(size: 17))
                .foregroundStyle(SettingsTokens.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.leading, SettingsTokens.rowLeading)
    }

    private var strip: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: max(0, rowWidth - Self.restingPeek), height: SettingsTokens.rowHeight)
                        .id(Self.startAnchor)

                    HStack(spacing: 0) {
                        ForEach(orderedIndices, id: \.self) { index in
                            swatch(index: index, scroller: scroller)
                        }
                    }
                    .padding(.leading, 5)
                    // Keeps the card colour running past the last swatch so the
                    // label stays covered when the strip is dragged fully open.
                    .padding(.trailing, 160)
                    .frame(height: SettingsTokens.rowHeight)
                    .background(SettingsTokens.groupCard)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x
            } action: { _, offset in
                let opened = offset > 2
                guard opened != isScrolledOpen else { return }
                withAnimation(.easeOut(duration: 0.25)) { isScrolledOpen = opened }
            }
            .overlay(alignment: .trailing) { trailingFade }
        }
    }

    private var trailingFade: some View {
        LinearGradient(
            stops: [
                .init(color: SettingsTokens.groupCard.opacity(0), location: 0),
                .init(color: SettingsTokens.groupCard.opacity(0.72), location: 0.46),
                .init(color: SettingsTokens.groupCard, location: 0.82),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 24)
        .opacity(isScrolledOpen ? 0 : 1)
        .allowsHitTesting(false)
    }

    private func swatch(index: Int, scroller: ScrollViewProxy) -> some View {
        let color = Color.themePalette[index]
        let isSelected = index == Color.normalizedThemeIndex(selectedIndex)

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                scroller.scrollTo(Self.startAnchor, anchor: .leading)
                selectedIndex = index
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: Self.swatchDiameter, height: Self.swatchDiameter)

                if isSelected {
                    Circle()
                        .stroke(SettingsTokens.groupCard, lineWidth: 2)
                        .frame(width: Self.swatchDiameter + 2, height: Self.swatchDiameter + 2)
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: Self.swatchDiameter + 5.5, height: Self.swatchDiameter + 5.5)
                }
            }
            .frame(width: Self.swatchCell, height: SettingsTokens.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Color.legacyThemeName(forThemeIndex: index))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
