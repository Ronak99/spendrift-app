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

    var body: some View {
        Picker(accessibilityContainerLabel, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(title(option)).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .modifier(SegmentedGlassModifier())
        .frame(height: 44)
        .onChange(of: selection) { _, newValue in
            onSelect?(newValue)
        }
        .accessibilityIdentifier(accessibilityContainerIdentifier)
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

/// Liquid Glass around the system segmented control on iOS 26.
/// Earlier systems keep the native segmented picker on its own.
private struct SegmentedGlassModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
        }
    }
}
