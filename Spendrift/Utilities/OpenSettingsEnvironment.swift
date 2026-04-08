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

/// Opens app settings from the navigation bar (see `ContentView` sheet).
struct ProfileSettingsToolbarButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(action: openSettings) {
            Image(systemName: "gear")
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityLabel("Profile and settings")
        .accessibilityIdentifier("openSettingsToolbar")
    }
}
