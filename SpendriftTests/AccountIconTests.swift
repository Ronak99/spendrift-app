//
//  AccountIconTests.swift
//  SpendriftTests
//

import Testing
@testable import Spendrift

struct AccountIconTests {
    @Test
    func selectableExcludesUnknown() {
        #expect(!AccountIcon.selectable.contains(.unknown))
        #expect(AccountIcon.selectable.count == AccountIcon.allCases.count - 1)
    }

    @Test
    func featuredIconsAreEightSelectableIcons() {
        #expect(AccountIcon.featuredForPicker.count == 8)
        #expect(Set(AccountIcon.featuredForPicker).count == 8)
        for icon in AccountIcon.featuredForPicker {
            #expect(AccountIcon.selectable.contains(icon))
        }
    }

    @Test
    func everyIconHasAPaletteEnamel() {
        for icon in AccountIcon.allCases {
            #expect(CategoryPalette.contains(icon.enamelHex), "\(icon.rawValue) enamel is off-palette")
            #expect(AccountEnamel.hex(for: icon) == icon.enamelHex)
        }
        #expect(AccountIcon.visa.enamelHex == "#9B7BFF")
        #expect(AccountIcon.wallet.enamelHex == "#FF9F6B")
    }

    @Test
    func everySelectableIconHasPickerMetadata() {
        for icon in AccountIcon.selectable {
            #expect(!icon.systemImageName.isEmpty, "\(icon.rawValue) has no symbol")
            #expect(!icon.pickerLabel.isEmpty, "\(icon.rawValue) has no label")
            #expect(!icon.searchKeywords.isEmpty, "\(icon.rawValue) has no keywords")
            #expect(!icon.pickerGroup.isEmpty, "\(icon.rawValue) has no group")
        }
    }

    @Test
    func pickerGroupsCoverEverySelectableIconExactlyOnce() {
        let grouped = AccountIcon.pickerGroups.flatMap(\.icons)
        #expect(grouped.count == AccountIcon.selectable.count)
        #expect(Set(grouped) == Set(AccountIcon.selectable))
        let titles = AccountIcon.pickerGroups.map(\.title)
        #expect(Set(titles).count == titles.count)
    }
}
