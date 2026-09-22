//
//  ExploreSettingsView.swift
//  Spendrift
//
//  Full-screen carousel of ways to capture money without living in the app:
//  speak, type, or import bank SMS through Shortcuts.
//
//  Layout note: the hero mark is the only thing that travels. Dots, copy, and
//  the call to action are single instances that stay put; the copy cross-fades
//  and the CTA symbol swaps in place while the mark slides under the finger.
//

import SwiftUI

struct ExploreSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage = 0
    @State private var dragTranslation: CGFloat = 0

    @Environment(\.openURL) private var openURL

    private let pages = ExploreShortcutPage.all

    private var accent: Color { AppTheme.accent }
    private var isDark: Bool { colorScheme == .dark }
    private var heroPrimary: Color { SettingsChrome.heroPrimary(isDark: isDark) }

    private var page: ExploreShortcutPage {
        pages[min(max(currentPage, 0), pages.count - 1)]
    }

    var body: some View {
        ZStack {
            SettingsAtmosphere(washColor: accent)

            GeometryReader { proxy in
                let slotWidth = Self.slotWidth(for: proxy.size.width)
                // Continuous carousel position: whole values sit on a page, the
                // fraction is however far the finger has dragged toward the next.
                let progress = CGFloat(currentPage) - dragTranslation / slotWidth

                VStack(spacing: 0) {
                    Spacer(minLength: 12)

                    ExploreHeroCarousel(
                        pages: pages,
                        progress: progress,
                        slotWidth: slotWidth,
                        accent: accent,
                        onSelect: { select($0) }
                    )
                    .frame(height: 196)
                    .padding(.bottom, 28)

                    ExplorePageIndicator(total: pages.count, progress: progress)
                        .padding(.bottom, 22)

                    copyBlock
                        .opacity(copyOpacity(slotWidth: slotWidth))

                    Spacer(minLength: 24)

                    footer
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(pageDrag(slotWidth: slotWidth))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Capture methods")
                .accessibilityValue(page.title)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: select(currentPage + 1)
                    case .decrement: select(currentPage - 1)
                    @unknown default: break
                    }
                }
            }
        }
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .tint(accent)
        .sensoryFeedback(.selection, trigger: currentPage)
        .onAppear {
            AudienceTags.markSeenExplore()
        }
    }

    // MARK: - Static chrome

    private var copyBlock: some View {
        VStack(spacing: 10) {
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(heroPrimary)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 28)
        }
        .id(currentPage)
        .transition(.opacity)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .top)
    }

    private var footer: some View {
        VStack(spacing: 14) {
            SettingsPrimaryButton(title: "Add shortcut", systemImage: page.icon) {
                guard let url = page.shortcutURL else { return }
                AudienceTags.markExploreShortcutAdded()
                openURL(url)
            }
            .opacity(page.shortcutURL == nil ? 0.45 : 1)
            .disabled(page.shortcutURL == nil)

            // Reserved slot so the CTA never shifts between pages.
            ZStack {
                if page.showsSetupSteps {
                    NavigationLink {
                        BankSMSSettingsView()
                    } label: {
                        Text("See setup steps")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(heroPrimary.opacity(0.7))
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    // MARK: - Paging

    /// Slot pitch for the carousel: wide enough to hold the hero plate, narrow
    /// enough that both neighbors stay visible at the edges.
    private static func slotWidth(for containerWidth: CGFloat) -> CGFloat {
        max(120, min(containerWidth * 0.42, 200))
    }

    private func pageDrag(slotWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragTranslation = rubberBanded(value.translation.width, slotWidth: slotWidth)
            }
            .onEnded { value in
                // Use the projected end so a flick pages even when it is short.
                let projected = rubberBanded(value.predictedEndTranslation.width, slotWidth: slotWidth)
                let threshold = slotWidth * 0.28
                var target = currentPage
                if projected <= -threshold {
                    target += 1
                } else if projected >= threshold {
                    target -= 1
                }
                settle(on: target)
            }
    }

    /// Damps the drag past the first and last page so the strip feels bounded.
    private func rubberBanded(_ translation: CGFloat, slotWidth: CGFloat) -> CGFloat {
        let maxTranslation = CGFloat(currentPage) * slotWidth
        let minTranslation = -CGFloat(pages.count - 1 - currentPage) * slotWidth
        if translation > maxTranslation {
            return maxTranslation + (translation - maxTranslation) * 0.3
        }
        if translation < minTranslation {
            return minTranslation + (translation - minTranslation) * 0.3
        }
        return translation
    }

    private func select(_ index: Int) {
        guard index != currentPage else { return }
        settle(on: index)
    }

    private func settle(on index: Int) {
        let target = min(max(index, 0), pages.count - 1)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            dragTranslation = 0
            currentPage = target
        }
    }

    /// Copy dims while the mark is in flight, then fades back in on the new page.
    private func copyOpacity(slotWidth: CGFloat) -> Double {
        let travelled = min(abs(dragTranslation) / slotWidth, 1)
        return 1 - 0.7 * Double(travelled)
    }
}

// MARK: - Page model

private struct ExploreShortcutPage: Identifiable {
    let id: Int
    let title: String
    let description: String
    let icon: String
    let shortcutURL: URL?
    let showsSetupSteps: Bool

    static let all: [ExploreShortcutPage] = [
        ExploreShortcutPage(
            id: 0,
            title: "Shout it out",
            description: "Save a transaction by speaking, anytime. Spendrift hears you even when the app is closed.",
            icon: "mic.fill",
            shortcutURL: OnboardingShortcutShareLinks.voiceRecordExpense,
            showsSetupSteps: false
        ),
        ExploreShortcutPage(
            id: 1,
            title: "Write it out",
            description: "Log an amount on the go from Shortcuts or Siri, without opening the app.",
            icon: "pencil",
            shortcutURL: OnboardingShortcutShareLinks.logExpenseAmount,
            showsSetupSteps: false
        ),
        ExploreShortcutPage(
            id: 2,
            title: "Import SMS",
            description: "Add this shortcut, then attach it to a Messages automation so bank SMS are logged as they arrive.",
            icon: "message.fill",
            shortcutURL: OnboardingShortcutShareLinks.logTransactionMessage,
            showsSetupSteps: true
        ),
    ]
}

// MARK: - Hero carousel (the only travelling element)

private struct ExploreHeroCarousel: View {
    let pages: [ExploreShortcutPage]
    let progress: CGFloat
    let slotWidth: CGFloat
    let accent: Color
    let onSelect: (Int) -> Void

    private var centerIndex: CGFloat { CGFloat(pages.count - 1) / 2 }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(pages) { page in
                let distance = min(abs(CGFloat(page.id) - progress), 1)
                CategoryEnamelTile(
                    systemImage: page.icon,
                    color: accent,
                    showsShadow: distance < 0.45
                )
                .frame(width: 88, height: 88)
                .scaleEffect(1 - 0.46 * distance)
                .opacity(1 - 0.74 * Double(distance))
                .frame(width: slotWidth)
                .contentShape(Rectangle())
                .onTapGesture { onSelect(page.id) }
            }
        }
        .offset(x: (centerIndex - progress) * slotWidth)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Indicator

private struct ExplorePageIndicator: View {
    let total: Int
    let progress: CGFloat

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { index in
                let weight = max(0, 1 - min(abs(CGFloat(index) - progress), 1))
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.22 + 0.78 * Double(weight)))
                    .frame(width: 7 + 13 * weight, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        ExploreSettingsView()
    }
    .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
