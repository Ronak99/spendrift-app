//
//  ColoredCategoriesTests.swift
//  SpendriftTests
//

import SwiftUI
import Testing
@testable import Spendrift

struct ColoredCategoriesTests {
    @Test
    func mapsDefaultCatalogNames() {
        #expect(ColoredCategories.swatch(forName: "Food") == .orange)
        #expect(ColoredCategories.swatch(forName: "Groceries") == .green)
        #expect(ColoredCategories.swatch(forName: "Transport") == .indigo)
        #expect(ColoredCategories.swatch(forName: "Bills & Utilities") == .blue)
        #expect(ColoredCategories.swatch(forName: "Rent") == .teal)
        #expect(ColoredCategories.swatch(forName: "Shopping") == .pink)
        #expect(ColoredCategories.swatch(forName: "Health") == .red)
        #expect(ColoredCategories.swatch(forName: "Salary") == .teal)
        #expect(ColoredCategories.swatch(forName: "Other Income") == .teal)
        #expect(ColoredCategories.swatch(forName: "Miscellaneous") == .gray)
    }

    @Test
    func mapsLegacyAliasesToTheSameHueAsTheirFamily() {
        #expect(ColoredCategories.swatch(forName: "Transportation") == .indigo)
        #expect(ColoredCategories.swatch(forName: "Bills") == .blue)
        #expect(ColoredCategories.swatch(forName: "Insurance") == .blue)
        #expect(ColoredCategories.swatch(forName: "Clothing") == .pink)
        #expect(ColoredCategories.swatch(forName: "Dividend") == .cyan)
    }

    @Test
    func lookupIsCaseAndWhitespaceInsensitive() {
        #expect(ColoredCategories.swatch(forName: "food") == .orange)
        #expect(ColoredCategories.swatch(forName: "  FOOD  ") == .orange)
    }

    @Test
    func customNamesAreStableAndNotGray() {
        let first = ColoredCategories.swatch(forName: "Coffee Shop")
        let second = ColoredCategories.swatch(forName: "Coffee Shop")
        #expect(first == second)
        #expect(first != .gray)
    }

    @Test
    func nameMapResolvesToTheCuratedPaletteTone() {
        // Shopping has no stored hex, so it falls through the name map. It has to
        // land on the palette's pink, not SwiftUI's much redder `.pink` (RON-231).
        #expect(ColoredCategories.color(forName: "Shopping").hexString == "#E27BD8")
        #expect(ColoredCategories.color(forName: "Food").hexString == "#FF9F6B")
        #expect(ColoredCategories.color(forName: "Health").hexString == "#FF6B6B")
    }

    @Test
    func seededCategoryWithoutHexMatchesTheCategoryChip() {
        let shopping = TransactionCategory(name: "Shopping", type: .expense, icon: .shopping)
        #expect(shopping.colorHex == nil)
        let sheetTint = ColoredCategories.color(for: shopping)?.hexString
        #expect(sheetTint == CategoryEnamel.color(for: shopping).hexString)
    }

    @Test
    func storedHexWinsOverNameMap() {
        let category = TransactionCategory(
            name: "Food",
            type: .expense,
            icon: .food,
            colorHex: "#6C8CFF"
        )
        #expect(CategoryPalette.normalizedHex(category.colorHex) == "#6C8CFF")
        #expect(ColoredCategories.swatch(forName: category.name) == .orange)
    }
}

struct CategoryEditorLogicTests {
    @Test
    func nameExistsIsCaseInsensitiveAndIgnoresSelf() {
        let food = TransactionCategory(name: "Food", type: .expense, icon: .food)
        let groceries = TransactionCategory(name: "Groceries", type: .expense, icon: .groceries)

        #expect(TransactionCategory.nameExists("food", in: [food, groceries]))
        #expect(TransactionCategory.nameExists("  FOOD  ", in: [food, groceries]))
        #expect(!TransactionCategory.nameExists("Coffee", in: [food, groceries]))
        #expect(!TransactionCategory.nameExists("Food", in: [food, groceries], excluding: food.id))
        #expect(!TransactionCategory.nameExists("   ", in: [food, groceries]))
    }

    @Test
    func suggestionsMatchCommonNames() {
        #expect(CategoryNameSuggestion.match(name: "Groceries")?.icon == .groceries)
        #expect(CategoryNameSuggestion.match(name: "rent")?.icon == .rent)
        #expect(CategoryNameSuggestion.match(name: "fuel")?.hex == "#FF9F6B")
        #expect(CategoryNameSuggestion.match(name: "x") == nil)
        #expect(CategoryNameSuggestion.match(name: "") == nil)
    }

    @Test
    func paletteNormalizesHex() {
        #expect(CategoryPalette.normalizedHex("#8bd17c") == "#8BD17C")
        #expect(CategoryPalette.normalizedHex("8BD17C") == "#8BD17C")
        #expect(CategoryPalette.normalizedHex("  ") == nil)
        #expect(CategoryPalette.contains("#8BD17C"))
        #expect(!CategoryPalette.contains("#FFFFFF"))
    }
}
