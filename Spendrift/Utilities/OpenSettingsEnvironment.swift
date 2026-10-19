//
//  OpenSettingsEnvironment.swift
//  Spendrift
//

import SwiftUI

private struct OpenSettingsActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsActionKey.self] }
        set { self[OpenSettingsActionKey.self] = newValue }
    }
}

/// Opens the Settings sheet (see `ContentView`). Secondary plate on purpose:
/// the add button beside it owns the inverted chrome.
struct ProfileSettingsToolbarButton: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button(action: openSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: 32, height: 32)
                .background(plate, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile and settings")
        .accessibilityIdentifier("openSettingsToolbar")
    }

    private var plate: Color {
        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    private var glyph: Color {
        isDark ? Color.white.opacity(0.8) : Color(hex: "#111111").opacity(0.7)
    }
}
