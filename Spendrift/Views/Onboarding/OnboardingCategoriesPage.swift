//
//  OnboardingCategoriesPage.swift
//  Spendrift
//

import SwiftUI
import SwiftData

struct OnboardingCategoriesPage: View {
    @Binding var choice: CategoryCatalogService.OnboardingChoice

    private let suggestedNames = TransactionCategory.defaultCategories().map(\.name)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text("Your Categories")
                        .font(.title2.bold())
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("We've added a short starter set. Keep them, start with just the essentials, or set up later.")
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)

                OnboardingCard(themeTint: OnboardingPageAccent.categories) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Suggested")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .textCase(.uppercase)
                            .tracking(0.6)

                        Text(suggestedNames.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(OnboardingTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().overlay(OnboardingTheme.textSecondary.opacity(0.25))

                        VStack(spacing: 12) {
                            choiceButton(
                                title: "Use suggested categories",
                                subtitle: "Recommended — add your own anytime",
                                isSelected: choice == .keepSuggested
                            ) {
                                choice = .keepSuggested
                            }

                            choiceButton(
                                title: "Start fresh",
                                subtitle: "Salary, Food, Transport & Miscellaneous only",
                                isSelected: choice == .startFresh
                            ) {
                                choice = .startFresh
                            }

                            choiceButton(
                                title: "I'll set this up later",
                                subtitle: "Keep suggested for now",
                                isSelected: choice == .skip
                            ) {
                                choice = .skip
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

    private func choiceButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? OnboardingPageAccent.categories : OnboardingTheme.textSecondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private enum OnboardingPageAccent {
    static let categories = Color(hex: "#F59E0B")
}
