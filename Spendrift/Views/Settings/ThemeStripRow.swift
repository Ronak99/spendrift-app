//
//  ThemeStripRow.swift
//  Spendrift
//
//  Theme picker as a single settings row: the swatches live in a horizontal
//  scroller that starts tucked against the trailing edge. Dragging it open
//  stops at the "Theme" label, and releasing midway snaps closed or fully open.
//

import SwiftUI

struct ThemeStripRow: View {
    @Binding var selectedIndex: Int
    let accent: Color
    let accentSoft: Color

    private static let startAnchor = "theme-strip-start"
    private static let rowSpace = "theme-strip-row"
    /// How much of the strip peeks out on the trailing edge at rest.
    private static let restingPeek: CGFloat = 64
    private static let swatchDiameter: CGFloat = 18
    /// Swatch diameter plus the gap, so cells tile at the same pitch the design uses.
    private static let swatchCell: CGFloat = 28
    /// Breathing room between the "Theme" text and the first swatch when open.
    private static let themeClearance: CGFloat = 10

    @State private var rowWidth: CGFloat = 0
    @State private var themeStopX: CGFloat = 0
    @State private var isScrolledOpen = false

    /// Selected colour leads, the rest keep their palette order behind it.
    private var orderedIndices: [Int] {
        let selected = Color.normalizedThemeIndex(selectedIndex)
        return [selected] + Color.themePalette.indices.filter { $0 != selected }
    }

    /// Fallback if the label has not reported its frame yet: icon tile, then "Theme".
    private var resolvedThemeStopX: CGFloat {
        if themeStopX > 0 { return themeStopX }
        return SettingsTokens.rowLeading
            + SettingsTokens.iconSize
            + SettingsTokens.iconGap
            + 52
            + Self.themeClearance
    }

    private var collapsedSpacerWidth: CGFloat {
        max(0, rowWidth - Self.restingPeek)
    }

    /// Width of the colour strip so its leading edge lands on `resolvedThemeStopX`.
    private var expandedStripWidth: CGFloat {
        max(0, rowWidth - resolvedThemeStopX)
    }

    private var expandedOffset: CGFloat {
        max(0, collapsedSpacerWidth - resolvedThemeStopX)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            label
            strip
        }
        .frame(height: SettingsTokens.rowHeight)
        .coordinateSpace(name: Self.rowSpace)
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
                .background(alignment: .leading) {
                    GeometryReader { proxy in
                        let stop = proxy.frame(in: .named(Self.rowSpace)).maxX + Self.themeClearance
                        Color.clear
                            .onAppear { themeStopX = stop }
                            .onChange(of: stop) { _, value in themeStopX = value }
                    }
                }
            Spacer(minLength: 0)
        }
        .padding(.leading, SettingsTokens.rowLeading)
    }

    private var strip: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: collapsedSpacerWidth, height: SettingsTokens.rowHeight)
                        .id(Self.startAnchor)

                    HStack(spacing: 0) {
                        ForEach(orderedIndices, id: \.self) { index in
                            swatch(index: index, scroller: scroller)
                        }
                    }
                    .padding(.leading, 5)
                    .frame(width: expandedStripWidth, alignment: .leading)
                    .frame(height: SettingsTokens.rowHeight)
                    .background(SettingsTokens.groupCard)
                }
            }
            .scrollTargetBehavior(ThemeStripSnapBehavior(expandedOffset: expandedOffset))
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

/// Snaps the strip to its tucked rest position or its fully expanded stop.
private struct ThemeStripSnapBehavior: ScrollTargetBehavior {
    var expandedOffset: CGFloat

    /// From rest, this much of the open distance is enough to finish opening.
    private static let expandCommit: CGFloat = 0.15
    /// From open, this much of the close distance is enough to finish closing.
    private static let collapseCommit: CGFloat = 0.30
    private static let flickThreshold: CGFloat = 120

    func updateTarget(_ target: inout ScrollTarget, context: ScrollTargetBehaviorContext) {
        let snapX: CGFloat
        if expandedOffset <= 0 {
            snapX = 0
        } else {
            let proposed = target.rect.minX
            let origin = context.originalTarget.rect.minX
            let velocity = context.velocity.dx
            let startedExpanded = origin > expandedOffset * 0.5

            if velocity > Self.flickThreshold {
                snapX = expandedOffset
            } else if velocity < -Self.flickThreshold {
                snapX = 0
            } else if startedExpanded {
                let closedFraction = (expandedOffset - proposed) / expandedOffset
                snapX = closedFraction >= Self.collapseCommit ? 0 : expandedOffset
            } else {
                snapX = proposed >= expandedOffset * Self.expandCommit ? expandedOffset : 0
            }
        }

        target.rect.origin.x = snapX
    }
}
