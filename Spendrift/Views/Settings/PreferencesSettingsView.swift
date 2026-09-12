//
//  PreferencesSettingsView.swift
//  Spendrift
//
//  Reminder controls on the same colour-wash canvas as the rest of Settings.
//

import SwiftUI

struct PreferencesSettingsView: View {
    var body: some View {
        SettingsScreen(title: "Preferences", watermarkIcon: "slider.horizontal.3") {
            NotificationsSettingsContent()
        }
    }
}

#Preview {
    NavigationStack {
        PreferencesSettingsView()
    }
}
