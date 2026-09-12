//
//  ChromeSegmentedPicker.swift
//  Spendrift
//
//  Shared expense / income (and other two-up) picker used by Categories,
//  the category editor, and the transaction editor so those surfaces stay
//  one control instead of three copies.
//

import SwiftUI

struct ChromeSegmentedPicker<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    var accessibilityContainerLabel: String = "Type"
    var accessibilityContainerIdentifier: String = "type-picker"
    let title: (Option) -> String
    var onSelect: ((Option) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDark: Bool { colorScheme == .dark }

    private var heroPrimary: Color {
        isDark ? .white : Color(hex: "#111111")
    }

    private var selectedFill: Color {
        isDark ? Color.white.opacity(0.9) : Color(hex: "#111111")
    }

    private var selectedForeground: Color {
        isDark ? Color(hex: "#111111") : .white
    }

    private var selectionMotion: Animation? {
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.black.opacity(isDark ? 0.3 : 0.08))
        )
        .animation(selectionMotion, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityContainerLabel)
        .accessibilityIdentifier(accessibilityContainerIdentifier)
    }

    private func segment(_ option: Option) -> some View {
        let isOn = selection == option
        let label = title(option)

        return Button {
            selection = option
            onSelect?(option)
        } label: {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(isOn ? selectedForeground : heroPrimary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn ? selectedFill : Color.primary.opacity(0.001))
                }
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(ChromeSegmentButtonStyle())
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension ChromeSegmentedPicker where Option: CaseIterable, Option: RawRepresentable, Option.AllCases == [Option], Option.RawValue == String {
    init(
        selection: Binding<Option>,
        accessibilityLabel: String = "Type",
        onSelect: ((Option) -> Void)? = nil
    ) {
        self.init(
            selection: selection,
            options: Array(Option.allCases),
            accessibilityContainerLabel: accessibilityLabel,
            title: { $0.rawValue.capitalized },
            onSelect: onSelect
        )
    }
}

/// Makes the whole padded segment tappable, not just the label text.
private struct ChromeSegmentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}
