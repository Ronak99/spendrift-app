//
//  AppUpdateSheet.swift
//  Spendrift
//
//  Shown on launch when a new App Store version is detected.
//  Optional updates are dismissible; mandatory updates block the app until the user updates.
//

import SwiftUI

struct AppUpdateSheet: View {
    let kind: UpdateKind
    let latestVersion: String?
    let storeURL: URL?

    @Environment(\.dismiss) private var dismiss

    // Amber for optional, red-orange for mandatory.
    private var accentColor: Color {
        kind == .mandatory ? Color(hex: "#FF6B35") : Color(hex: "#F59E0B")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OnboardingSheetAtmosphericBackground(tintColor: accentColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                heroSection
                    .padding(.bottom, 36)

                infoCard
                    .padding(.horizontal, 20)

                Spacer(minLength: 32)

                actionButtons
                    .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(kind == .mandatory)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                GlowingHeroGlow(color: accentColor, size: 45)
                GlowingHeroMark(
                    assetName: OnboardingVisualAsset.heroMark,
                    color: accentColor,
                    size: 45,
                    liquidGlassTint: accentColor
                )
            }

            VStack(spacing: 10) {
                if let version = latestVersion {
                    Text("v\(version) available")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(accentColor.opacity(0.15))
                                .strokeBorder(accentColor.opacity(0.35), lineWidth: 0.75)
                        )
                }

                Text(headlineText)
                    .font(.title2.bold())
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Info card

    private var infoCard: some View {
        OnboardingCard(themeTint: accentColor) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(bulletPoints, id: \.title) { bullet in
                    OnboardingFeatureRow(
                        icon: bullet.icon,
                        color: bullet.color,
                        title: bullet.title,
                        description: bullet.description
                    )
                }
            }
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                if let url = storeURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Update Now")
                    .font(.headline)
                    .foregroundStyle(OnboardingTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(accentColor))
            }
            .padding(.horizontal, 24)

            if kind == .optional {
                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Copy

    private var headlineText: String {
        switch kind {
        case .optional: "A new version is ready"
        case .mandatory: "Update required"
        }
    }

    private var subtitleText: String {
        switch kind {
        case .optional:
            "A new version of Spendrift is available with improvements and fixes."
        case .mandatory:
            "This version of Spendrift is no longer supported. Please update to continue."
        }
    }

    private var bulletPoints: [(icon: String, color: Color, title: String, description: String)] {
        switch kind {
        case .optional:
            [
                ("sparkles", Color(hex: "#F59E0B"), "What's new",
                 "Bug fixes, performance improvements, and new features await."),
                ("arrow.down.circle.fill", Color(hex: "#34C759"), "Free update",
                 "Updates are free — tap Update Now to grab it in the background."),
            ]
        case .mandatory:
            [
                ("exclamationmark.triangle.fill", Color(hex: "#FF6B35"), "Update required",
                 "This version is no longer supported. Update to keep using Spendrift."),
                ("lock.shield.fill", Color(hex: "#34C759"), "Your data is safe",
                 "All your transactions and accounts are preserved across updates."),
            ]
        }
    }
}

// MARK: - Preview

#Preview("Optional Update") {
    AppUpdateSheet(
        kind: .optional,
        latestVersion: "1.1.0",
        storeURL: nil
    )
}

#Preview("Mandatory Update") {
    AppUpdateSheet(
        kind: .mandatory,
        latestVersion: "2.0.0",
        storeURL: nil
    )
}
