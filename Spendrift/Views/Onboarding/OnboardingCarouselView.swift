//
//  OnboardingCarouselView.swift
//  Spendrift
//
//  NeatPass-style carousel: deep dark background, glowing hero, FeatureRow list,
//  pill pager, haptic on completion.
//

import SwiftUI
import SwiftData

struct OnboardingCarouselView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var onboardingVersion: Int
    @State private var currentPage = 0

    private let totalPages = 3

    private static let heroConfigurations: [OnboardingHeroPageConfiguration] = [
        OnboardingHeroPageConfiguration(
            mark: .asset(
                name: OnboardingVisualAsset.heroMark,
                bundle: nil,
                templateTint: false,
                cornerFraction: 0.224
            ),
            glowColor: OnboardingTheme.accent,
            size: 45
        ),
        OnboardingHeroPageConfiguration(
            mark: .sfSymbol("bolt.circle.fill"),
            glowColor: Color(hex: "#A78BFA"),
            size: 45
        ),
        OnboardingHeroPageConfiguration(
            mark: .sfSymbol("checkmark.seal.fill"),
            glowColor: Color(hex: "#34C759"),
            size: 45
        ),
    ]

    private var activeSheetTint: Color {
        let configs = Self.heroConfigurations
        guard !configs.isEmpty else { return OnboardingTheme.accent }
        let index = min(max(0, currentPage), configs.count - 1)
        return configs[index].glowColor
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            OnboardingSheetAtmosphericBackground(tintColor: activeSheetTint)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.48), value: currentPage)

            VStack(spacing: 0) {
                Spacer(minLength: 35)
                OnboardingSharedHeroView(
                    currentPage: currentPage,
                    configurations: Self.heroConfigurations
                )
                .padding(.top, 40)
                .padding(.bottom, 8)

                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    ShortcutsPage()
                        .tag(1)
                    GetStartedPage()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomChrome
                .background(OnboardingTheme.background.ignoresSafeArea(edges: .bottom))
        }
        .preferredColorScheme(.dark)
    }

    private var isOnLastOnboardingPage: Bool {
        currentPage >= totalPages - 1
    }

    private var bottomChrome: some View {
        VStack(spacing: 16) {
            PillPageIndicator(total: totalPages, current: currentPage)

            Button {
                if currentPage < totalPages - 1 {
                    withAnimation(.easeInOut(duration: 0.35)) { currentPage += 1 }
                } else {
                    completeOnboarding()
                }
            } label: {
                Text(isOnLastOnboardingPage ? "Get Started" : "Next")
                    .font(.headline)
                    .contentTransition(.interpolate)
                    .foregroundStyle(OnboardingTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(isOnLastOnboardingPage ? OnboardingTheme.success : Color.white)
                    )
            }
            .animation(.easeInOut(duration: 0.35), value: currentPage)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
    }

    private func completeOnboarding() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Analytics.capture(.onboardingCompleted, [Analytics.Key.version: OnboardingCarouselView.currentVersion])
        onboardingVersion = OnboardingCarouselView.currentVersion
    }

    /// Bump to re-show onboarding on major updates.
    static let currentVersion = 2
}

private enum OnboardingPageAccent {
    static let welcome = OnboardingTheme.accent
    static let shortcuts = Color(hex: "#A78BFA")
    static let getStarted = Color(hex: "#34C759")
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    private let features: [(icon: String, color: Color, title: String, description: String)] = [
        ("creditcard.fill", Color(hex: "#5E5CE6"), "Track Every Expense",
         "Log income and spending across multiple accounts with a tap."),
        ("mic.fill", Color(hex: "#A78BFA"), "Voice Capture",
         "Speak an expense and Spendrift parses the amount, category and account."),
        ("folder.fill", Color(hex: "#F59E0B"), "Smart Categories",
         "Organise transactions into custom categories for instant insights."),
        ("lock.shield.fill", Color(hex: "#34C759"), "Private by Default",
         "Your ledger stays on this device and in your private iCloud. Optional AI features only run when you choose them."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text("Welcome to Spendrift")
                        .font(.title.bold())
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("The simple, private way to track your money.")
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                OnboardingCard(themeTint: OnboardingPageAccent.welcome) {
                    VStack(spacing: 20) {
                        ForEach(features, id: \.title) { f in
                            OnboardingFeatureRow(
                                icon: f.icon,
                                color: f.color,
                                title: f.title,
                                description: f.description
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 120)
            }
        }
        .scrollDisabled(true)
    }
}

// MARK: - Page 2: Siri & Shortcuts

private struct ShortOnboardingBullet: Identifiable {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let description: String
    let shortcutURL: URL?
}

private struct ShortcutsPage: View {
    private let bullets: [ShortOnboardingBullet] = [
        ShortOnboardingBullet(
            id: "voice",
            icon: "mic.fill",
            color: Color(hex: "#5E5CE6"),
            title: "Voice Record Expense",
            description: "Tap to add this shortcut.",
            shortcutURL: OnboardingShortcutShareLinks.voiceRecordExpense
        ),
        ShortOnboardingBullet(
            id: "amount",
            icon: "textformat.123",
            color: Color(hex: "#A78BFA"),
            title: "Log Expense Amount",
            description: "Tap to add this shortcut.",
            shortcutURL: OnboardingShortcutShareLinks.logExpenseAmount
        ),
        ShortOnboardingBullet(
            id: "quick-access",
            icon: "sparkles",
            color: Color(hex: "#F59E0B"),
            title: "Quick Access",
            description:
                "Tie created shortcuts to quick accessibility options.",
            shortcutURL: nil
        ),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 12)
                VStack(spacing: 8) {
                    Text("Siri & Shortcuts")
                        .font(.title2.bold())
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    (
                        Text("Tap ").foregroundStyle(OnboardingTheme.textSecondary)
                            + Text("Voice Record Expense").fontWeight(.semibold).foregroundStyle(OnboardingTheme.textPrimary)
                            + Text(" or ").foregroundStyle(OnboardingTheme.textSecondary)
                            + Text("Log Expense Amount").fontWeight(.semibold).foregroundStyle(OnboardingTheme.textPrimary)
                            + Text(" to open a shareable link—add the shortcut, then use Siri or the Shortcuts app anytime.")
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    )
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)

                OnboardingCard(themeTint: OnboardingPageAccent.shortcuts) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add shortcuts")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        VStack(spacing: 20) {
                            ForEach(bullets) { b in
                                OnboardingFeatureRow(
                                    icon: b.icon,
                                    color: b.color,
                                    title: b.title,
                                    description: b.description,
                                    shortcutURL: b.shortcutURL
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 120)
            }
        }
            .scrollDisabled(true)
    }
}

// MARK: - Page 4: Get Started

private struct GetStartedPage: View {
    private let highlights: [(icon: String, color: Color, text: String)] = [
        ("checkmark.circle.fill", Color(hex: "#34C759"), "Track spending across accounts"),
        ("checkmark.circle.fill", Color(hex: "#34C759"), "Log by voice, type, or manual entry"),
        ("checkmark.circle.fill", Color(hex: "#34C759"), "Use Siri to log without opening the app"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text("You're all set.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Here's what's waiting for you.")
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                OnboardingCard(themeTint: OnboardingPageAccent.getStarted) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(highlights, id: \.text) { h in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: h.icon)
                                    .font(.title3)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(h.color)
                                Text(h.text)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(OnboardingTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 120)
            }
        }
        .scrollDisabled(true)
    }
}

#Preview {
    OnboardingCarouselView(onboardingVersion: .constant(0))
}
