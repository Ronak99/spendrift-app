//
//  PreferencesSettingsView.swift
//  Spendrift
//
//  Theme and reminder controls in one place, on the same colour-wash
//  canvas as the rest of Settings.
//

import SwiftUI

struct PreferencesSettingsView: View {
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    private var accent: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    var body: some View {
        SettingsScreen(title: "Preferences", watermarkIcon: "slider.horizontal.3") {
            Section {
                ThemeStripRow(
                    selectedIndex: $selectedThemeIndex,
                    accent: accent
                )
                .listItemPositioned(.only)
            }

            NotificationsSettingsContent()
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selectedThemeIndex)
    }
}

#Preview {
    NavigationStack {
        PreferencesSettingsView()
    }
}
