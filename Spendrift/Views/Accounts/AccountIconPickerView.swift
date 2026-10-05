//
//  AccountIconPickerView.swift
//  Spendrift
//

import SwiftUI

struct AccountIconPickerView: View {
    @Binding var selectedIcon: AccountIcon
    let accentHex: String
    var onDone: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var accent: Color { Color(hex: accentHex) }

    private var filteredGroups: [(title: String, icons: [AccountIcon])] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let groups = AccountIcon.pickerGroups
        guard !needle.isEmpty else { return groups }
        return groups.compactMap { group in
            let icons = group.icons.filter { icon in
                (icon.pickerLabel + " " + icon.searchKeywords + " "
                    + icon.rawValue)
                    .lowercased()
                    .contains(needle)
            }
            guard !icons.isEmpty else { return nil }
            return (group.title, icons)
        }
    }

    private var saveBackground: Color {
        Color.white.opacity(0.92)
    }

    private var saveForeground: Color {
        Color(hex: "#111111")
    }

    private var saveButton: some View {
        Button {
            onDone?()
            dismiss()
        } label: {
            Text("Save")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(saveBackground, in: Capsule())
                .foregroundStyle(saveForeground)
                // A bare `Text` is the one thing in a toolbar item the navigation bar is
                // willing to compress, so on narrow iPhones — and at larger Dynamic Type,
                // where the inline title claims more of the bar — the label truncated to
                // "S…". Pinning the capsule at its ideal width makes the bar shrink the
                // title instead, the same way the pickers' `addButton` holds a fixed frame.
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if filteredGroups.isEmpty {
                    Text("No icons match “\(query)”")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(filteredGroups, id: \.title) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.8)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)

                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(
                                            .flexible(),
                                            spacing: 12
                                        ),
                                        count: 5
                                    ),
                                    spacing: 12
                                ) {
                                    ForEach(group.icons, id: \.self) { icon in
                                        AccountIconCell(
                                            icon: icon,
                                            isSelected: selectedIcon == icon,
                                            accent: accent
                                        ) {
                                            selectedIcon = icon
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppTheme.listBackground.ignoresSafeArea())
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                prompt: "Search \(AccountIcon.selectable.count) icons"
            )
            .toolbar {
                CustomSheetCloseToolbarItem()

                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        saveButton
                    }
                }
            }
        }
    }
}

struct AccountIconCell: View {
    let icon: AccountIcon
    let isSelected: Bool
    let accent: Color
    var action: () -> Void

    private var motionToken: String {
        "\(isSelected)-\(AppMotion.colorToken(accent))"
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon.systemImageName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(
                    isSelected ? accent : Color.primary.opacity(0.62)
                )
                .frame(height: 24)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isSelected
                                ? accent.opacity(0.15)
                                : Color.primary.opacity(0.06)
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            isSelected ? accent : Color.clear,
                            lineWidth: 1.5
                        )
                }
        }
        .buttonStyle(.plain)
        .washMotion(value: motionToken)
        .accessibilityLabel(icon.pickerLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var icon = AccountIcon.bankAccountOne
    AccountIconPickerView(selectedIcon: $icon, accentHex: icon.enamelHex)
}
