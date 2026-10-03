//
//  CategoryIconPickerView.swift
//  Spendrift
//

import SwiftUI

struct CategoryIconPickerView: View {
    @Binding var selectedIcon: CategoryIcon
    let accentHex: String
    var onDone: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var accent: Color { Color(hex: accentHex) }

    private var filteredGroups: [(title: String, icons: [CategoryIcon])] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let groups = CategoryIcon.pickerGroups
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
                                        CategoryIconCell(
                                            icon: icon,
                                            isSelected: selectedIcon == icon,
                                            accent: accent,
                                            showsLabel: false
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
            .searchable(text: $query, prompt: "Search \(CategoryIcon.selectable.count) icons")
            .toolbar {
                SheetDismissToolbarItem()
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

struct CategoryIconCell: View {
    let icon: CategoryIcon
    let isSelected: Bool
    let accent: Color
    var showsLabel: Bool = true
    var action: () -> Void

    private var motionToken: String {
        "\(isSelected)-\(AppMotion.colorToken(accent))"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon.systemImageName)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? accent : Color.primary.opacity(0.62))
                    .frame(height: 24)

                if showsLabel {
                    Text(icon.pickerLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, showsLabel ? 13 : 16)
            .padding(.bottom, showsLabel ? 10 : 16)
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
        .washMotion(value: motionToken)
        .accessibilityLabel(icon.pickerLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var icon = CategoryIcon.groceries
    CategoryIconPickerView(selectedIcon: $icon, accentHex: CategoryPalette.defaultExpenseHex)
}
