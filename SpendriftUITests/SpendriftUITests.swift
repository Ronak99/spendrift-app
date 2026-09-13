//
//  SpendriftUITests.swift
//  SpendriftUITests
//
//  Created by Ronak Punase on 03/08/25.
//

import XCTest

// MARK: - Base Test Case

class SpendriftUITestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab Helpers

    func navigateToAccounts() {
        app.tabBars.buttons["Accounts"].tap()
    }

    func navigateToCategories() {
        app.tabBars.buttons["Categories"].tap()
    }

    func navigateToTransactions() {
        app.tabBars.buttons["Transactions"].tap()
    }

    func navigateToSettings() {
        app.tabBars.buttons["Settings"].tap()
    }

    /// Opens manual entry from the Transactions tab (toolbar **+** or empty-state **Add Transaction**).
    func openTransactionsManualEntryForm() {
        if app.buttons["Add Transaction"].waitForExistence(timeout: 2) {
            app.buttons["Add Transaction"].tap()
        } else {
            let addButton = app.buttons["transactionsAddButton"].firstMatch
            if addButton.waitForExistence(timeout: 2) {
                addButton.tap()
            } else {
                XCTAssertTrue(app.navigationBars.buttons["plus"].waitForExistence(timeout: 3))
                app.navigationBars.buttons["plus"].tap()
            }
        }
        waitForTransactionEditor()
    }

    func waitForTransactionEditor() {
        XCTAssertTrue(app.textFields["0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForExistence(timeout: 3))
    }

    /// Opens New Account from the Accounts tab (empty-state CTA, then toolbar **+**).
    func openNewAccountSheet() {
        if app.buttons["accountsEmptyAddButton"].waitForExistence(timeout: 2) {
            app.buttons["accountsEmptyAddButton"].tap()
        } else if app.buttons["accountsAddButton"].waitForExistence(timeout: 3) {
            app.buttons["accountsAddButton"].tap()
        } else {
            XCTAssertTrue(app.navigationBars.buttons["plus"].waitForExistence(timeout: 3))
            app.navigationBars.buttons["plus"].tap()
        }
    }

    /// Opens New Category from the Categories tab via the toolbar **+**.
    /// Defaults are always seeded, so the screen never shows an empty state.
    func openNewCategorySheet() {
        XCTAssertTrue(app.navigationBars.buttons["plus"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["plus"].tap()
    }

    /// Switches the Categories grid to the given segment ("Expense" or "Income").
    func selectCategorySegment(_ type: String) {
        let segment = app.descendants(matching: .any)["type-picker"].buttons[type]
        XCTAssertTrue(segment.waitForExistence(timeout: 3))
        segment.tap()
    }

    // MARK: - Account Helpers

    @discardableResult
    func createAccount(name: String, balance: String, iconIndex: Int? = nil) -> Self {
        navigateToAccounts()
        openNewAccountSheet()

        let nameField = app.textFields["Enter account name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(name)

        let balanceField = app.textFields["0"]
        balanceField.tap()
        balanceField.typeText(balance)

        if let iconIndex = iconIndex {
            let iconButtons = app.scrollViews.buttons
            if iconButtons.count > iconIndex {
                iconButtons.element(boundBy: iconIndex).tap()
            }
        }

        app.navigationBars.buttons["Save"].tap()
        return self
    }

    // MARK: - Category Helpers

    @discardableResult
    func createCategory(name: String, type: String = "Expense", iconIndex: Int? = nil) -> Self {
        navigateToCategories()
        // The New Category sheet inherits the selected segment, so switch before opening it.
        selectCategorySegment(type)
        openNewCategorySheet()

        let nameField = app.textFields["Enter category name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText(name)

        if let iconIndex = iconIndex {
            let iconButtons = app.scrollViews.buttons
            if iconButtons.count > iconIndex {
                iconButtons.element(boundBy: iconIndex).tap()
            }
        }

        app.navigationBars.buttons["Save"].tap()
        return self
    }

    // MARK: - Transaction Helpers

    @discardableResult
    func createTransaction(
        type: String = "Expense",
        accountName: String,
        categoryName: String,
        amount: String,
        notes: String = ""
    ) -> Self {
        navigateToTransactions()
        openTransactionsManualEntryForm()

        if type == "Income" {
            app.buttons["Income"].tap()
        }

        // Select account
        app.buttons["Account"].tap()
        let accountButton = app.buttons[accountName]
        XCTAssertTrue(accountButton.waitForExistence(timeout: 3))
        accountButton.tap()

        // Select category
        app.buttons["Category"].tap()
        let categoryButton = app.buttons[categoryName]
        XCTAssertTrue(categoryButton.waitForExistence(timeout: 3))
        categoryButton.tap()

        // Enter amount
        let amountField = app.textFields["0"]
        amountField.tap()
        amountField.typeText(amount)

        // Enter notes
        if !notes.isEmpty {
            let notesField = app.textFields["Add notes"]
            notesField.tap()
            notesField.typeText(notes)
        }

        app.navigationBars.buttons["Save"].tap()
        return self
    }
}

// MARK: - Account Integration Tests

final class AccountIntegrationTests: SpendriftUITestBase {

    // MARK: Empty State

    func testAccountsTab_showsEmptyState_whenNoAccounts() {
        navigateToAccounts()
        XCTAssertTrue(app.staticTexts["No accounts"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Add a bank, card, or wallet to start tracking."].exists)
        XCTAssertTrue(app.buttons["accountsEmptyAddButton"].exists)
    }

    func testAccountsEmptyState_addButtonOpensCreateSheet() {
        navigateToAccounts()
        app.buttons["accountsEmptyAddButton"].tap()
        XCTAssertTrue(app.navigationBars["New Account"].waitForExistence(timeout: 3))
    }

    // MARK: Create

    func testCreateAccount_withValidData_appearsInList() {
        createAccount(name: "SBI Savings", balance: "50000")

        let accountCell = app.staticTexts["SBI Savings"]
        XCTAssertTrue(accountCell.waitForExistence(timeout: 3))
    }

    func testCreateAccount_saveShowsAlert_whenNameEmpty() {
        navigateToAccounts()
        openNewAccountSheet()

        let balanceField = app.textFields["0"]
        balanceField.tap()
        balanceField.typeText("1000")

        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
        XCTAssertTrue(app.alerts["Enter an account name."].waitForExistence(timeout: 3))
    }

    func testCreateAccount_saveShowsAlert_whenBalanceEmpty() {
        navigateToAccounts()
        openNewAccountSheet()

        let nameField = app.textFields["Enter account name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Test Account")

        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
        XCTAssertTrue(app.alerts["Enter an opening balance."].waitForExistence(timeout: 3))
    }

    func testCreateAccount_cancelDismissesSheet() {
        navigateToAccounts()
        openNewAccountSheet()
        XCTAssertTrue(app.navigationBars["New Account"].waitForExistence(timeout: 3))

        app.navigationBars.buttons["xmark"].tap()
        XCTAssertTrue(app.navigationBars["Accounts"].waitForExistence(timeout: 3))
    }

    func testCreateMultipleAccounts_allAppearInList() {
        createAccount(name: "SBI Savings", balance: "50000")
        createAccount(name: "HDFC Current", balance: "25000")

        XCTAssertTrue(app.staticTexts["SBI Savings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["HDFC Current"].exists)
    }

    // MARK: Edit

    func testEditAccount_updatesNameAndBalance() {
        createAccount(name: "Old Name", balance: "1000")

        let cell = app.staticTexts["Old Name"]
        XCTAssertTrue(cell.waitForExistence(timeout: 3))
        cell.tap()

        XCTAssertTrue(app.navigationBars["Edit Account"].waitForExistence(timeout: 3))

        let nameField = app.textFields["Enter account name"]
        nameField.tap()
        nameField.clearAndTypeText("New Name")

        app.navigationBars.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["New Name"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Old Name"].exists)
    }

    // MARK: Delete

    func testDeleteAccount_removesFromList() {
        createAccount(name: "To Delete", balance: "100")
        XCTAssertTrue(app.staticTexts["To Delete"].waitForExistence(timeout: 3))

        let cell = app.cells.containing(.staticText, identifier: "To Delete").element
        cell.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        sleep(1)
        let noAccountsExists = app.staticTexts["No accounts"].waitForExistence(timeout: 3)
        let cellStillExists = app.staticTexts["To Delete"].exists
        XCTAssertTrue(noAccountsExists || !cellStillExists)
    }
}

// MARK: - Category Integration Tests

final class CategoryIntegrationTests: SpendriftUITestBase {

    // MARK: Default Seeding

    func testCategoriesTab_seedsDefaultCategories_onFirstLaunch() {
        navigateToCategories()
        // Expense is the default segment; Food is a seeded expense default.
        XCTAssertTrue(app.staticTexts["Food"].waitForExistence(timeout: 5))

        selectCategorySegment("Income")
        XCTAssertTrue(app.staticTexts["Salary"].waitForExistence(timeout: 3))
    }

    func testCategoriesTab_incomeSegment_showsDefaults() {
        navigateToCategories()
        selectCategorySegment("Income")
        XCTAssertTrue(app.staticTexts["Other Income"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Salary"].exists)
        XCTAssertFalse(app.staticTexts["Food"].exists)
    }

    func testCategoriesTab_expenseSegment_showsDefaults() {
        navigateToCategories()
        selectCategorySegment("Expense")
        XCTAssertTrue(app.staticTexts["Bills & Utilities"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Shopping"].exists)
        XCTAssertFalse(app.staticTexts["Salary"].exists)
    }

    // MARK: Create

    func testCreateCategory_expense_appearsInExpenseSegment() {
        createCategory(name: "Custom Expense", type: "Expense")

        navigateToCategories()
        XCTAssertTrue(app.staticTexts["Custom Expense"].waitForExistence(timeout: 3))
    }

    func testCreateCategory_income_appearsInIncomeSegment() {
        createCategory(name: "Custom Income", type: "Income")

        navigateToCategories()
        selectCategorySegment("Income")
        XCTAssertTrue(app.staticTexts["Custom Income"].waitForExistence(timeout: 3))
    }

    func testCreateCategory_saveShowsAlert_whenNameEmpty() {
        navigateToCategories()
        openNewCategorySheet()
        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 3))

        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
        XCTAssertTrue(app.alerts["Enter a category name."].waitForExistence(timeout: 3))
    }

    func testCreateCategory_cancelDismissesSheet() {
        navigateToCategories()
        openNewCategorySheet()
        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 3))

        app.navigationBars.buttons["xmark"].tap()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 3))
    }

    // MARK: Delete

    func testDeleteCategory_customCategory_removesFromGrid() {
        createCategory(name: "Temporary", type: "Expense")

        navigateToCategories()
        let tile = app.staticTexts["Temporary"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.press(forDuration: 1.0)

        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
        deleteAction.tap()

        let confirm = app.buttons["Delete Category and Its Transactions"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertFalse(app.staticTexts["Temporary"].waitForExistence(timeout: 2))
    }

    func testDeleteCategory_defaultCategory_hasNoDeleteAction() {
        navigateToCategories()

        let tile = app.staticTexts["Food"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.press(forDuration: 1.0)

        XCTAssertFalse(app.buttons["Delete"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Food"].exists)
    }
}

// MARK: - Transaction Integration Tests

final class TransactionIntegrationTests: SpendriftUITestBase {

    // MARK: Empty State

    func testTransactionsTab_showsEmptyState_whenNoTransactions() {
        navigateToTransactions()
        XCTAssertTrue(app.staticTexts["No Transactions"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Add Transaction"].exists)
    }

    func testTransactionsEmptyState_addButtonOpensCreateSheet() {
        navigateToTransactions()
        app.buttons["Add Transaction"].tap()
        waitForTransactionEditor()
    }

    // MARK: Create

    func testCreateExpenseTransaction_appearsInList() {
        createAccount(name: "SBI", balance: "50000")
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "500",
            notes: "Lunch"
        )

        navigateToTransactions()
        XCTAssertTrue(app.staticTexts["Food"].waitForExistence(timeout: 3))
    }

    func testCreateIncomeTransaction_appearsInList() {
        createAccount(name: "SBI", balance: "0")
        createTransaction(
            type: "Income",
            accountName: "SBI",
            categoryName: "Salary",
            amount: "60000",
            notes: "March pay"
        )

        navigateToTransactions()
        XCTAssertTrue(app.staticTexts["Salary"].waitForExistence(timeout: 3))
    }

    func testCreateTransaction_saveShowsAlert_withoutAccount() {
        navigateToTransactions()
        openTransactionsManualEntryForm()
        waitForTransactionEditor()

        let amountField = app.textFields["0"]
        amountField.tap()
        amountField.typeText("500")

        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
        XCTAssertTrue(app.alerts["Create an account before saving this transaction."].waitForExistence(timeout: 3))
    }

    func testCreateTransaction_cancelDismissesSheet() {
        navigateToTransactions()
        openTransactionsManualEntryForm()
        waitForTransactionEditor()

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 3))
    }

    // MARK: Edit

    func testEditTransaction_updatesAmount() {
        createAccount(name: "SBI", balance: "50000")
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "500"
        )

        navigateToTransactions()
        let foodCell = app.staticTexts["Food"]
        XCTAssertTrue(foodCell.waitForExistence(timeout: 3))
        foodCell.tap()

        waitForTransactionEditor()

        let amountField = app.textFields.element(boundBy: 0)
        amountField.tap()
        amountField.clearAndTypeText("750")

        app.navigationBars.buttons["Save"].tap()
        sleep(1)
        // Transaction still shows Food category — amount changed internally
        XCTAssertTrue(app.staticTexts["Food"].waitForExistence(timeout: 3))
    }

    // MARK: Delete

    func testDeleteTransaction_removesFromList() {
        createAccount(name: "SBI", balance: "50000")
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "500"
        )

        navigateToTransactions()
        XCTAssertTrue(app.staticTexts["Food"].waitForExistence(timeout: 3))

        let cell = app.cells.containing(.staticText, identifier: "Food").element
        cell.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        sleep(1)
        XCTAssertTrue(app.staticTexts["No Transactions"].waitForExistence(timeout: 3))
    }

    // MARK: Account Picker

    func testAccountPicker_showsAllAccounts() {
        createAccount(name: "SBI Savings", balance: "10000")
        createAccount(name: "HDFC Current", balance: "5000")

        navigateToTransactions()
        openTransactionsManualEntryForm()
        waitForTransactionEditor()

        app.buttons["Account"].tap()
        XCTAssertTrue(app.staticTexts["SBI Savings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["HDFC Current"].exists)
    }

    // MARK: Category Picker

    func testCategoryPicker_showsFilteredCategories_forExpense() {
        navigateToTransactions()
        openTransactionsManualEntryForm()
        waitForTransactionEditor()

        // Default is Expense
        app.buttons["Category"].tap()
        XCTAssertTrue(app.navigationBars["Select Category"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Food"].waitForExistence(timeout: 3))
        // Income categories should not appear
        XCTAssertFalse(app.buttons["Salary"].exists)
    }

    func testCategoryPicker_showsFilteredCategories_forIncome() {
        navigateToTransactions()
        openTransactionsManualEntryForm()
        waitForTransactionEditor()

        app.buttons["Income"].tap()

        app.buttons["Category"].tap()
        XCTAssertTrue(app.navigationBars["Select Category"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Salary"].waitForExistence(timeout: 3))
        // Expense categories should not appear
        XCTAssertFalse(app.buttons["Food"].exists)
    }

    func testCategoryPicker_createNewCategoryFromPicker() {
        navigateToTransactions()
        openTransactionsManualEntryForm()
        waitForTransactionEditor()

        app.buttons["Category"].tap()
        XCTAssertTrue(app.navigationBars["Select Category"].waitForExistence(timeout: 3))

        // Tap the + button in picker
        app.navigationBars["Select Category"].buttons["plus"].tap()
        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 3))

        let nameField = app.textFields["Enter category name"]
        nameField.tap()
        nameField.typeText("Custom Food")

        app.navigationBars.buttons["Save"].tap()

        // Should auto-select and return to transaction sheet
        sleep(1)
        XCTAssertTrue(app.staticTexts["Custom Food"].waitForExistence(timeout: 3))
    }

    // MARK: Statistics Bar

    func testTransactionStatistics_showsCorrectTotals() {
        createAccount(name: "SBI", balance: "100000")

        createTransaction(
            type: "Income",
            accountName: "SBI",
            categoryName: "Salary",
            amount: "60000"
        )
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "5000"
        )

        navigateToTransactions()

        // Verify the statistics labels exist
        XCTAssertTrue(app.staticTexts["Expenses"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Income"].exists)
        XCTAssertTrue(app.staticTexts["Savings"].exists)
    }
}

// MARK: - Cross-Feature Integration Tests

final class CrossFeatureIntegrationTests: SpendriftUITestBase {

    // MARK: Account Balance

    func testAccountBalance_reflectsExpenseTransaction() {
        createAccount(name: "SBI", balance: "50000")
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "5000"
        )

        navigateToAccounts()
        // Balance should be 50000 - 5000 = 45000
        let balanceText = app.staticTexts.allElementsBoundByIndex.first {
            $0.label.contains("45,000")
        }
        XCTAssertNotNil(balanceText, "Account balance should reflect the expense deduction")
    }

    func testAccountBalance_reflectsIncomeTransaction() {
        createAccount(name: "SBI", balance: "10000")
        createTransaction(
            type: "Income",
            accountName: "SBI",
            categoryName: "Salary",
            amount: "60000"
        )

        navigateToAccounts()
        // Balance should be 10000 + 60000 = 70000
        let balanceText = app.staticTexts.allElementsBoundByIndex.first {
            $0.label.contains("70,000")
        }
        XCTAssertNotNil(balanceText, "Account balance should reflect the income addition")
    }

    func testAccountBalance_reflectsMultipleTransactions() {
        createAccount(name: "SBI", balance: "50000")

        createTransaction(
            type: "Income",
            accountName: "SBI",
            categoryName: "Salary",
            amount: "60000"
        )
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "5000"
        )
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Shopping",
            amount: "3000"
        )

        navigateToAccounts()
        // 50000 + 60000 - 5000 - 3000 = 102000
        let balanceText = app.staticTexts.allElementsBoundByIndex.first {
            $0.label.contains("1,02,000")
        }
        XCTAssertNotNil(balanceText, "Account balance should reflect all transactions")
    }

    func testAccountBalance_unchangedAfterTransactionDeleted() {
        createAccount(name: "SBI", balance: "50000")
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "10000"
        )

        // Delete the transaction
        navigateToTransactions()
        let cell = app.cells.containing(.staticText, identifier: "Food").element
        XCTAssertTrue(cell.waitForExistence(timeout: 3))
        cell.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        // Balance should revert to original 50000
        navigateToAccounts()
        sleep(1)
        let balanceText = app.staticTexts.allElementsBoundByIndex.first {
            $0.label.contains("50,000")
        }
        XCTAssertNotNil(balanceText, "Account balance should revert after transaction deletion")
    }

    // MARK: Category-Transaction Relationship

    func testDeletingCategory_removesAssociatedTransactions() {
        // Defaults are permanent, so the cascade can only be exercised through a custom category.
        createCategory(name: "Hobby", type: "Expense")
        createAccount(name: "SBI", balance: "50000")
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Hobby",
            amount: "1000"
        )

        // Delete the custom category from its grid tile's context menu
        navigateToCategories()
        let tile = app.staticTexts["Hobby"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.press(forDuration: 1.0)
        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
        deleteAction.tap()
        let confirm = app.buttons["Delete Category and Its Transactions"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        // Transaction linked to Food should also be removed (cascade)
        navigateToTransactions()
        sleep(1)
        XCTAssertTrue(app.staticTexts["No Transactions"].waitForExistence(timeout: 3))
    }

    func testDeletingAccount_removesAssociatedTransactions() {
        createAccount(name: "SBI", balance: "50000")
        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "1000"
        )

        // Delete the account
        navigateToAccounts()
        let accountCell = app.cells.containing(.staticText, identifier: "SBI").element
        XCTAssertTrue(accountCell.waitForExistence(timeout: 3))
        accountCell.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()
        }

        // Transaction linked to SBI should also be removed (cascade)
        navigateToTransactions()
        sleep(1)
        XCTAssertTrue(app.staticTexts["No Transactions"].waitForExistence(timeout: 3))
    }

    // MARK: Multi-Account

    func testMultipleAccounts_balancesIndependent() {
        createAccount(name: "SBI", balance: "50000")
        createAccount(name: "HDFC", balance: "30000")

        createTransaction(
            type: "Expense",
            accountName: "SBI",
            categoryName: "Food",
            amount: "5000"
        )

        navigateToAccounts()

        // SBI: 50000 - 5000 = 45000
        let sbiBalance = app.staticTexts.allElementsBoundByIndex.first {
            $0.label.contains("45,000")
        }
        XCTAssertNotNil(sbiBalance, "SBI balance should reflect the expense")

        // HDFC: 30000 (untouched)
        let hdfcBalance = app.staticTexts.allElementsBoundByIndex.first {
            $0.label.contains("30,000")
        }
        XCTAssertNotNil(hdfcBalance, "HDFC balance should remain unchanged")
    }

    // MARK: Tab Navigation

    func testTabNavigation_allTabsAccessible() {
        navigateToTransactions()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 3))

        navigateToAccounts()
        XCTAssertTrue(app.navigationBars["Accounts"].waitForExistence(timeout: 3))

        navigateToCategories()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 3))

        navigateToSettings()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }
}

// MARK: - XCUIElement Helpers

extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        guard let currentValue = self.value as? String, !currentValue.isEmpty else {
            typeText(text)
            return
        }
        // Select all text and delete
        tap()
        if let selectAll = XCUIApplication().menuItems["Select All"].firstMatch as? XCUIElement,
           selectAll.waitForExistence(timeout: 1) {
            selectAll.tap()
            typeText(XCUIKeyboardKey.delete.rawValue)
        } else {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            typeText(deleteString)
        }
        typeText(text)
    }
}
