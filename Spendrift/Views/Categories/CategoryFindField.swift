//
//  CategoryFindField.swift
//  Spendrift
//
//  Find chrome for category trays. Same track-fill well as
//  ChromeSegmentedPicker, so search sits in the tray instead of a
//  second system search bar.
//

import SwiftUI

struct CategoryFindField: View {
    @Binding var query: String
    var prompt: String = "Find a category"
    var autoFocus: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    private var isDark: Bool { colorScheme == .dark }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(heroPrimary.opacity(0.42))
                .accessibilityHidden(true)
                .onTapGesture { isFocused = true }

            TextField(prompt, text: $query)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(heroPrimary)
                .tint(heroPrimary)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("Find a category")
                .accessibilityLabel("Find a category")
                .onSubmit {
                    isFocused = false
                }

            let hasQuery = !CategorySearch.needle(from: query).isEmpty
            Button {
                query = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(heroPrimary.opacity(hasQuery ? 0.42 : 0))
            }
            .buttonStyle(.plain)
            .disabled(!hasQuery)
            .accessibilityHidden(!hasQuery)
            .accessibilityLabel("Clear search")
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(isDark ? 0.3 : 0.08))
        )
        .onAppear {
            guard autoFocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }
}

/// Empty recipe when a query has no chips in the current type.
struct CategorySearchMiss: View {
    let query: String
    let type: CategoryType
    var otherType: CategoryType? = nil
    var otherMatchCount: Int = 0
    var otherMatchName: String? = nil
    var onShowOtherType: (() -> Void)? = nil
    var onAdd: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var addBackground: Color {
        isDark ? Color.white.opacity(0.92) : Color(hex: "#111111")
    }

    private var addForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    private var trimmedQuery: String {
        CategorySearch.needle(from: query)
    }

    private var showsOtherType: Bool {
        otherType != nil && otherMatchCount > 0
    }

    private var title: String {
        if showsOtherType, otherMatchCount == 1, let otherMatchName, !otherMatchName.isEmpty {
            return otherMatchName
        }
        if showsOtherType, let otherType {
            return "In \(otherType.rawValue.capitalized)"
        }
        return "Nothing matches"
    }

    private var bodyCopy: String {
        if showsOtherType, let otherType {
            if otherMatchCount == 1 {
                return "This is an \(otherType.rawValue) category."
            }
            return "\(otherMatchCount) \(otherType.rawValue) categories match."
        }
        return "Add it, or try another name."
    }

    private var actionTitle: String {
        if showsOtherType, let otherType {
            return "Show \(otherType.rawValue.capitalized)"
        }
        if trimmedQuery.count <= 18, !trimmedQuery.isEmpty {
            return "Add “\(trimmedQuery)”"
        }
        return "Add category"
    }

    var body: some View {
        VStack(spacing: 16) {
            CategoryEnamelTile(
                systemImage: CategoryPalette.defaultIcon(for: otherType ?? type).systemImageName,
                color: Color(hex: CategoryPalette.defaultHex(for: otherType ?? type))
            )
            .frame(width: 88, height: 88)
            .padding(.top, 28)

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(heroPrimary)
                .multilineTextAlignment(.center)

            Text(bodyCopy)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                if showsOtherType {
                    onShowOtherType?()
                } else {
                    onAdd()
                }
            }) {
                Text(actionTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(addBackground, in: Capsule())
                    .foregroundStyle(addForeground)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Find field") {
    @Previewable @State var query = "lunch"
    CategoryFindField(query: $query)
        .padding(24)
        .background(AppTheme.listBackground)
}

#Preview("Miss") {
    CategorySearchMiss(
        query: "Coffee",
        type: .expense,
        onAdd: {}
    )
    .background(AppTheme.listBackground)
}
