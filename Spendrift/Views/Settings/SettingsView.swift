//
//  SettingsView.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

// MARK: - Shortcut card model

private struct AppShortcutItem: Identifiable {
    let id: String
    let title: String
    let url: URL?
}

// MARK: - Shortcut card view

private struct ShortcutCard: View {
    let item: AppShortcutItem

    private let cardColor = Color(hex: "#7551e0")

    var body: some View {
        Button {
            guard let url = item.url else { return }
            UIApplication.shared.open(url)
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardColor)

                VStack(alignment: .leading, spacing: 0) {
                    Image("OnboardingHeroMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer()

                    Text(item.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                .padding(14)
            }
            .frame(height: 130)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings view

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeColor") private var themeColorName: String = "Blue"

    @State private var showFeatureRequest = false

    private let shortcuts: [AppShortcutItem] = [
        AppShortcutItem(
            id: "voice",
            title: "Speak Expense",
            url: OnboardingShortcutShareLinks.voiceRecordExpense
        ),
        AppShortcutItem(
            id: "amount",
            title: "Type Expense",
            url: OnboardingShortcutShareLinks.logExpenseAmount
        ),
    ]
    
    private let themeColors: [(name: String, color: Color)] = [
        ("Cyan", Color(hex: "#22D3EE")),
        ("Blue", Color(hex: "#3B82F6")),
        ("Purple", Color(hex: "#A78BFA")),
        ("Pink", Color(hex: "#EC4899")),
        ("Red", Color(hex: "#EF4444")),
        ("Orange", Color(hex: "#F59E0B")),
        ("Green", Color(hex: "#34D399")),
        ("Teal", Color(hex: "#14B8A6"))
    ]

    private var shareAccent: Color {
        Color.themeColors[themeColorName] ?? .blue
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(themeColors, id: \.name) { themeColor in
                            Button(action: {
                                themeColorName = themeColor.name
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(themeColor.color)
                                        .frame(width: 50, height: 50)
                                    
                                    if themeColorName == themeColor.name {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Theme")
                }

                Section {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(shortcuts) { shortcut in
                            ShortcutCard(item: shortcut)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Siri & Shortcuts")
                } footer: {
                    Text("Tap a card to add the shortcut to your device, then trigger it with Siri or the Shortcuts app.")
                        .font(.footnote)
                }

                Section {
                    Button {
                        showFeatureRequest = true
                    } label: {
                        featureRequestBanner
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Feedback")
                }

                Section {
                    ShareLink(
                        item: AppShareContent.fullShareText,
                        subject: Text("An app I think you’d enjoy"),
                        message: Text(AppShareContent.shareMessage),
                        preview: SharePreview("Spendrift", icon: Image(systemName: "chart.pie.fill"))
                    ) {
                        shareInviteBanner
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Share")
                } footer: {
                    Text("Pass it along, great apps spread by happy users.")
                        .font(.footnote)
                }

            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showFeatureRequest) {
                FeatureRequestView()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var featureRequestBanner: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                shareAccent.opacity(0.35),
                                shareAccent.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(shareAccent)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text("Request a Feature")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Have an idea that would make Spendrift better? Share it with us.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var shareInviteBanner: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                shareAccent.opacity(0.35),
                                shareAccent.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(shareAccent)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 6) {
                Text("Know someone who’d love Spendrift?")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Invite your friends and help them feel on top of their money.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.largeTitle)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(shareAccent, .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    SettingsView()
}
