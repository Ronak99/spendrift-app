//
//  DeveloperUnlockSheet.swift
//  Spendrift
//
//  Password prompt shown after tapping the Settings version label five times.
//  A match against DEVELOPER_PASSWORD unlocks the developer section for testers.
//

import SwiftUI
import UIKit

struct DeveloperUnlockSheet: View {
    /// Called once the password matches. The sheet dismisses itself.
    let onUnlock: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var showsError = false
    @State private var failedAttempts = 0
    @FocusState private var fieldFocused: Bool

    private var accent: Color { AppTheme.accent }

    private var canSubmit: Bool {
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            SettingsScreen(title: "Developer mode") {
                Section {
                    HStack(spacing: 14) {
                        CategoryEnamelTile(
                            systemImage: "key.fill",
                            color: accent,
                            showsShadow: false
                        )
                        .frame(width: SettingsTokens.iconSize, height: SettingsTokens.iconSize)

                        SecureField("Password", text: $password)
                            .font(.system(size: 16, weight: .semibold))
                            .tint(AppTheme.cursor)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .focused($fieldFocused)
                            .onSubmit(submit)
                            .onChange(of: password) { _, _ in showsError = false }
                    }
                    .padding(.horizontal, 6)
                    .listItemPositioned(.only)
                    .modifier(ShakeEffect(shakes: CGFloat(failedAttempts)))
                } footer: {
                    Text(showsError ? "Incorrect password." : "Enter the tester password to show developer tools.")
                        .font(.system(size: 12))
                        .foregroundStyle(showsError ? Color.red : SettingsTokens.textSecondary)
                }

                Section {
                    SettingsPrimaryButton(title: "Unlock", systemImage: "lock.open.fill", action: submit)
                        .opacity(canSubmit ? 1 : 0.45)
                        .disabled(!canSubmit)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listItemPositioned(.only)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        guard canSubmit else { return }
        guard DeveloperMode.isPassphrase(password) else {
            showsError = true
            password = ""
            withAnimation(.default) { failedAttempts += 1 }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onUnlock()
        dismiss()
    }
}

/// Horizontal shake for a rejected password; animates as `shakes` increments.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 4), y: 0))
    }
}

#Preview {
    Text("Settings")
        .sheet(isPresented: .constant(true)) {
            DeveloperUnlockSheet {}
        }
}
