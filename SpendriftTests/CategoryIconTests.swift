//
//  CategoryIconTests.swift
//  SpendriftTests
//

import Testing
@testable import Spendrift

struct CategoryIconTests {
    /// Raw values are persisted on TransactionCategory, so none of these may ever be renamed.
    private static let shippedRawValues = [
        "dividend", "friends", "salary", "coupons", "refunds", "sale",
        "bills", "education", "entertainment", "food", "health", "home",
        "investments", "shopping", "sport", "transportation", "baby",
        "beauty", "clothing", "tax", "electronics", "insurance",
        "groceries", "rent", "miscellaneous", "unknown"
    ]

    @Test
    func alreadyShippedRawValuesStillDecode() {
        for raw in Self.shippedRawValues {
            #expect(CategoryIcon(rawValue: raw) != nil, "Lost persisted icon “\(raw)”")
        }
    }

    @Test
    func selectableExcludesUnknownAndStaysLarge() {
        #expect(!CategoryIcon.selectable.contains(.unknown))
        #expect(CategoryIcon.selectable.count == CategoryIcon.allCases.count - 1)
        #expect(CategoryIcon.selectable.count > 100)
    }

    @Test
    func everySelectableIconHasPickerMetadata() {
        for icon in CategoryIcon.selectable {
            #expect(!icon.systemImageName.isEmpty, "\(icon.rawValue) has no symbol")
            #expect(!icon.pickerLabel.isEmpty, "\(icon.rawValue) has no label")
            #expect(!icon.searchKeywords.isEmpty, "\(icon.rawValue) has no keywords")
            #expect(!icon.pickerGroup.isEmpty, "\(icon.rawValue) has no group")
        }
    }

    @Test
    func pickerLabelsAreUnique() {
        let labels = CategoryIcon.selectable.map(\.pickerLabel)
        #expect(Set(labels).count == labels.count)
    }

    @Test
    func pickerGroupsCoverEverySelectableIconExactlyOnce() {
        let grouped = CategoryIcon.pickerGroups.flatMap(\.icons)
        #expect(grouped.count == CategoryIcon.selectable.count)
        #expect(Set(grouped) == Set(CategoryIcon.selectable))
        let titles = CategoryIcon.pickerGroups.map(\.title)
        #expect(Set(titles).count == titles.count)
    }

    @Test
    func featuredIconsAreSelectable() {
        for icon in CategoryIcon.featuredForPicker {
            #expect(CategoryIcon.selectable.contains(icon))
        }
    }

    @Test
    func keywordSearchFindsNewIcons() {
        func icon(matching needle: String) -> CategoryIcon? {
            CategoryIcon.selectable.first { candidate in
                (candidate.pickerLabel + " " + candidate.searchKeywords + " " + candidate.rawValue)
                    .lowercased()
                    .contains(needle)
            }
        }
        #expect(icon(matching: "broadband") == .internet)
        #expect(icon(matching: "fastag") == .tolls)
        #expect(icon(matching: "dentist") == .dental)
        #expect(icon(matching: "bitcoin") == .crypto)
    }
}
