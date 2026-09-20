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
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let groups = AccountIcon.pickerGroups
        guard !needle.isEmpty else { return groups }
        return groups.compactMap { group in
            let icons = group.icons.filter { icon in
                (icon.pickerLabel + " " + icon.searchKeywords + " " + icon.rawValue)
                    .lowercased()
                    .contains(needle)
            }
            guard !icons.isEmpty else { return nil }
            return (group.title, icons)
        }
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
                                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
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
            .searchable(text: $query, prompt: "Search \(AccountIcon.selectable.count) icons")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(accent)
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

    var body: some View {
        Button(action: action) {
            Image(systemName: icon.systemImageName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(isSelected ? accent : Color.primary.opacity(0.62))
                .frame(height: 24)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.15) : Color.primary.opacity(0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.pickerLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var icon = AccountIcon.bankAccountOne
    AccountIconPickerView(selectedIcon: $icon, accentHex: icon.enamelHex)
}
