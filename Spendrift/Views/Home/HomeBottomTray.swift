//
//  HomeBottomTray.swift
//  Spendrift
//
//  One global create. The pill reads "Add transaction" on every tab and is the
//  only control that makes one; the mic speaks one; the tray holds the slower
//  ways in - receipts, statements and bank SMS.
//

import SwiftUI

// MARK: - Liquid Glass surfaces
//
// The tray's three controls are native Liquid Glass on iOS 26: true translucent
// material with its own specular highlight, shadow and interactive squish on
// press, grouped in one `GlassEffectContainer` so the mic and more orbs blend
// into the Add transaction capsule as they pass close to it instead of reading
// as three separate layers. Earlier systems fall back to the flat tinted circles
// and the ink capsule this tray always drew.

/// Groups the tray's glass controls so nearby surfaces sample and blend as one
/// layer. Plain passthrough before iOS 26.
private struct TrayGlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { content }
        } else {
            content
        }
    }
}

private extension View {
    /// Liquid Glass circle on iOS 26, tinted when the control reads as "on"
    /// (the tray menu open). Falls back to the flat translucent fill this app
    /// used before Liquid Glass.
    @ViewBuilder
    func glassOrb(tint: Color?) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
            } else {
                self.glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            self
                .background(tint?.opacity(0.18) ?? AppTheme.glass, in: Circle())
                .overlay {
                    Circle().strokeBorder(tint?.opacity(0.36) ?? AppTheme.glassEdge, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 15, y: 8)
        }
    }

    /// Liquid Glass capsule tinted with the app's ink chrome, so the one global
    /// create action keeps reading as the primary control once it is glass.
    /// Falls back to the flat ink capsule.
    @ViewBuilder
    func glassActionCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(AppTheme.actionBackground).interactive(), in: .capsule)
        } else {
            self
                .background(AppTheme.actionBackground, in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
        }
    }
}

struct HomeBottomTray: View {
    @Binding var isMenuOpen: Bool
    let voiceDisabled: Bool
    let onAddTransaction: () -> Void
    let onSpeak: () -> Void

    var body: some View {
        TrayGlassGroup {
            HStack(spacing: 12) {
                orb(
                    systemImage: "tray.and.arrow.down",
                    iconTint: isMenuOpen ? AppTheme.atmosphere : AppTheme.inkSecondary,
                    glassTint: isMenuOpen ? AppTheme.atmosphere : nil,
                    label: "More ways to add"
                ) {
                    isMenuOpen.toggle()
                }

                orb(
                    systemImage: "mic.fill",
                    iconTint: voiceDisabled ? AppTheme.inkTertiary : AppTheme.microphone,
                    glassTint: nil,
                    label: "Speak a transaction",
                    action: onSpeak
                )
                .disabled(voiceDisabled)

                Button(action: onAddTransaction) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        Text("Add transaction")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .foregroundStyle(AppTheme.actionForeground)
                    .glassActionCapsule()
                }
                .buttonStyle(HomePressStyle(scale: 0.98))
                .accessibilityIdentifier("addTransactionCTA")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background {
            LinearGradient(
                colors: [AppTheme.canvas.opacity(0), AppTheme.canvas.opacity(0.88)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func orb(
        systemImage: String,
        iconTint: Color,
        glassTint: Color?,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(iconTint)
                .frame(width: 58, height: 58)
                .glassOrb(tint: glassTint)
        }
        .buttonStyle(HomePressStyle(scale: 0.94))
        .accessibilityLabel(label)
    }
}

/// The slower capture paths, grown out of the tray orb.
struct CaptureTrayMenu: View {
    let onScanReceipt: () -> Void
    let onImportStatement: () -> Void
    let onBankSMS: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            row(
                systemImage: "camera",
                color: AppTheme.atmosphere,
                title: "Scan a receipt",
                subtitle: "Photograph a bill or pick one from your library",
                action: onScanReceipt
            )
            HomeRowDivider()
            row(
                systemImage: "doc.text",
                color: Color(hex: "#6C8CFF"),
                title: "Import a statement",
                subtitle: "Read a bank PDF and pick the rows to keep",
                action: onImportStatement
            )
            HomeRowDivider()
            row(
                systemImage: "message",
                color: CategoryEnamel.uncategorized,
                title: "Bank SMS",
                subtitle: "Log transactions as the messages arrive",
                action: onBankSMS
            )
            HomeRowDivider()
            Text("Receipts and statements are read by an AI service. Bank SMS needs a Shortcuts automation, set up once.")
                .font(.system(size: 11.5))
                .foregroundStyle(AppTheme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.horizontal, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(AppTheme.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(AppTheme.glassEdge, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 25, y: 18)
        .padding(.horizontal, 20)
    }

    private func row(
        systemImage: String,
        color: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                EnamelBadge(systemImage: systemImage, color: color, side: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.inkTertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 1))
    }
}
