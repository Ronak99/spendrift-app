//
//  HomeBottomTray.swift
//  Spendrift
//
//  One global create. The pill reads "Add transaction" on every tab and is the
//  only control that makes one; the mic speaks one; the tray menu holds the
//  slower ways in - receipts and statements.
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
    /// Liquid Glass circle on iOS 26. Falls back to the flat translucent fill
    /// this app used before Liquid Glass.
    @ViewBuilder
    func glassOrb() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .circle)
        } else {
            self
                .background(AppTheme.glass, in: Circle())
                .overlay {
                    Circle().strokeBorder(AppTheme.glassEdge, lineWidth: 1)
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
    let voiceDisabled: Bool
    let onAddTransaction: () -> Void
    let onSpeak: () -> Void
    let onScanReceipt: () -> Void
    let onImportStatement: () -> Void

    var body: some View {
        TrayGlassGroup {
            HStack(spacing: 12) {
                captureMenu

                Button(action: onSpeak) {
                    orbIcon(
                        systemImage: "mic.fill",
                        tint: voiceDisabled ? AppTheme.inkTertiary : AppTheme.microphone
                    )
                }
                .buttonStyle(HomePressStyle(scale: 0.94))
                .accessibilityLabel("Speak a transaction")
                .disabled(voiceDisabled)

                Button(action: onAddTransaction) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        Text("Add transaction")
                            .font(.system(size: 16, weight: .semibold))
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

    /// The slower capture paths. A native menu, so it grows out of the orb as
    /// system Liquid Glass with the platform's own haptics and accessibility.
    private var captureMenu: some View {
        Menu {
            Button(action: onScanReceipt) {
                Label {
                    Text("Scan a Receipt")
                    Text("Photograph or pick a bill")
                } icon: {
                    Image(systemName: "camera")
                }
            }
            Button(action: onImportStatement) {
                Label {
                    Text("Import Bank Statement")
                    Text("Pick rows from a bank PDF")
                } icon: {
                    Image(systemName: "doc.text")
                }
            }
        } label: {
            orbIcon(systemImage: "ellipsis", tint: AppTheme.inkSecondary)
        }
        // Keep the written order even though the menu opens upward from the tray.
        .menuOrder(.fixed)
        .accessibilityLabel("More ways to add")
        .accessibilityIdentifier("captureMenu")
    }

    private func orbIcon(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 22))
            .foregroundStyle(tint)
            .frame(width: 58, height: 58)
            .glassOrb()
    }
}
