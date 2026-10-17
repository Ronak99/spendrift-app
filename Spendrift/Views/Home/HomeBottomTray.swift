//
//  HomeBottomTray.swift
//  Spendrift
//
//  One global create. The pill reads "Add transaction" on every tab and is the
//  only control that makes one; the mic speaks one; the tray holds the slower
//  ways in - receipts, statements and bank SMS.
//

import SwiftUI

struct HomeBottomTray: View {
    @Binding var isMenuOpen: Bool
    let voiceDisabled: Bool
    let onAddTransaction: () -> Void
    let onSpeak: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            orb(
                systemImage: "tray.and.arrow.down",
                tint: isMenuOpen ? AppTheme.atmosphere : AppTheme.inkSecondary,
                isOn: isMenuOpen,
                label: "More ways to add"
            ) {
                isMenuOpen.toggle()
            }

            orb(
                systemImage: "mic.fill",
                tint: voiceDisabled ? AppTheme.inkTertiary : AppTheme.microphone,
                isOn: false,
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
                .background(AppTheme.actionBackground, in: Capsule())
                .foregroundStyle(AppTheme.actionForeground)
                .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
            }
            .buttonStyle(HomePressStyle(scale: 0.98))
            .accessibilityIdentifier("addTransactionCTA")
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
        tint: Color,
        isOn: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(tint)
                .frame(width: 58, height: 58)
                .background(
                    isOn ? AppTheme.atmosphere.opacity(0.18) : AppTheme.glass,
                    in: Circle()
                )
                .overlay {
                    Circle().strokeBorder(
                        isOn ? AppTheme.atmosphere.opacity(0.36) : AppTheme.glassEdge,
                        lineWidth: 1
                    )
                }
                .shadow(color: .black.opacity(0.25), radius: 15, y: 8)
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
