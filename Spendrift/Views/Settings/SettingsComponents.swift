//
//  SettingsComponents.swift
//  Spendrift
//
//  Shared tokens and chrome for settings screens. Atmosphere, canvas, and
//  capsule controls match Transactions, Categories, and the editors so
//  Settings feels like the same box.
//

import SwiftUI
import UIKit

enum SettingsTokens {
    static let groupCard = AppTheme.listGroupBackground
    static let chevron = Color.primary.opacity(0.28)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    static let iconSize: CGFloat = 42
    static let iconGap: CGFloat = 14
}

enum SettingsChrome {
    static func canvas(isDark: Bool) -> Color {
        isDark ? Color(hex: "#0A0A0B") : AppTheme.listBackground
    }

    static func heroPrimary(isDark: Bool) -> Color {
        isDark ? .white : Color(hex: "#111111")
    }

    static func addBackground(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
    }

    static func addForeground(isDark: Bool) -> Color {
        isDark ? Color(hex: "#111111") : .white
    }
}

/// Colour-wash canvas plus the ultra-light watermark used on ledger screens.
struct SettingsAtmosphere: View {
    let washColor: Color
    var watermarkIcon: String = "gearshape"
    var animationToken: Int = 0

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SettingsChrome.canvas(isDark: isDark)

            ColorWashBackground(color: washColor, isDark: isDark)
                .frame(height: 320)
                .frame(maxHeight: .infinity, alignment: .top)

            Image(systemName: watermarkIcon)
                .font(.system(size: 176, weight: .ultraLight))
                .foregroundStyle(SettingsChrome.heroPrimary(isDark: isDark).opacity(isDark ? 0.10 : 0.08))
                .offset(x: 40, y: -28)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .contentTransition(.opacity)
                .washMotion(value: watermarkIcon)
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: animationToken)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: watermarkIcon)
    }
}

/// Trailing value for settings rows (status, quota, time). Plain type, not a chip.
struct SettingsValueLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
    }
}

struct SettingsIconTile: View {
    let systemName: String
    let accent: Color
    var size: CGFloat = SettingsTokens.iconSize

    var body: some View {
        CategoryEnamelTile(
            systemImage: systemName,
            color: accent,
            showsShadow: false
        )
        .frame(width: size, height: size)
    }
}

/// Compact capsule used in toolbars, matching Save on the editors.
struct SettingsCapsuleLabel: View {
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(SettingsChrome.addBackground(isDark: isDark), in: Capsule())
            .foregroundStyle(SettingsChrome.addForeground(isDark: isDark))
    }
}

/// Full-width capsule used as a screen-level action.
struct SettingsPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(SettingsChrome.addBackground(isDark: isDark), in: Capsule())
            .foregroundStyle(SettingsChrome.addForeground(isDark: isDark))
        }
        .buttonStyle(.plain)
    }
}

struct SettingsScreen<Content: View>: View {
    let title: String
    var watermarkIcon: String = "gearshape"
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String, watermarkIcon: String = "gearshape", @ViewBuilder content: () -> Content) {
        self.title = title
        self.watermarkIcon = watermarkIcon
        self.content = content()
    }

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .softScrollEdge()
        .background {
            SettingsAtmosphere(
                washColor: AppTheme.atmosphere,
                watermarkIcon: watermarkIcon
            )
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .tint(AppTheme.atmosphere)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
