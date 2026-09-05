//
//  ColoredCategoriesTests.swift
//  SpendriftTests
//

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
}
