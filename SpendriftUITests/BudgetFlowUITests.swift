//
//  BudgetFlowUITests.swift
//  SpendriftUITests
//
//  Set a monthly budget, then give one category a cap through "Add a category
//  budget". Picking the category used to freeze the app.
//

import XCTest

final class BudgetFlowUITests: SpendriftUITestBase {
    func testAddCategoryBudget_afterMonthlyBudget_opensCategoryEditor() {
        navigateToHome()
        setMonthlyBudget("60000")

        let addLink = app.buttons["Add a category budget"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()

        XCTAssertTrue(app.navigationBars["Budget"].waitForExistence(timeout: 3))
        let food = app.buttons.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(food.waitForExistence(timeout: 3))
        food.tap()

        // The category editor opens on its Budget field.
        let budgetField = app.textFields["Category budget"]
        XCTAssertTrue(budgetField.waitForExistence(timeout: 5), "Category editor never appeared")
        budgetField.tap()
        budgetField.typeText("8000")

        app.navigationBars.buttons["Save"].tap()

        // Back on Home, the capped row is listed and the app still answers touches.
        XCTAssertTrue(app.staticTexts["Food"].waitForExistence(timeout: 5))
        navigateToTransactions()
        XCTAssertEqual(paneTitle(), "Transactions")
    }

    func testBudgetPicker_createCategory_opensNewCategoryEditor() {
        navigateToHome()
        setMonthlyBudget("60000")

        let addLink = app.buttons["Add a category budget"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 5))
        addLink.tap()

        let create = app.buttons["budgetCreateCategory"]
        XCTAssertTrue(create.waitForExistence(timeout: 3))
        create.tap()

        XCTAssertTrue(app.navigationBars["New Category"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Category budget"].exists, "A new expense category offers its budget field")
    }

    /// The account editor builds its View Transactions link the same way the category
    /// editor does; opening it over Home must leave the app responsive.
    func testOpenAccountEditor_editorResponds() {
        createAccount(name: "SBI", balance: "100")
        let row = app.buttons["SBI"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.textFields["Enter account name"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["xmark"].tap()
        XCTAssertEqual(paneTitle(), "Accounts")
    }

    func testOpenCategoryFromGrid_editorResponds() {
        navigateToCategories()
        let food = app.buttons["Food"]
        XCTAssertTrue(food.waitForExistence(timeout: 5))
        food.tap()
        XCTAssertTrue(app.textFields["Enter category name"].waitForExistence(timeout: 5))
        let budgetField = app.textFields["Category budget"]
        XCTAssertTrue(budgetField.waitForExistence(timeout: 5))
        budgetField.tap()
        budgetField.typeText("5000")
        XCTAssertTrue(app.navigationBars.buttons["Save"].waitForExistence(timeout: 5))
    }

    /// Opens the total budget sheet from whichever entry Home shows, and saves `amount`.
    private func setMonthlyBudget(_ amount: String) {
        let setOne = app.buttons["Set one"]
        let setMonthly = app.buttons["Set a monthly budget"]
        let editLabel = app.buttons["Edit monthly budget"]

        if setOne.waitForExistence(timeout: 3) {
            setOne.tap()
        } else if setMonthly.exists {
            setMonthly.tap()
        } else {
            XCTAssertTrue(editLabel.waitForExistence(timeout: 3))
            editLabel.tap()
        }

        let field = app.textFields["Monthly budget"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.clearAndTypeText(amount)
        app.navigationBars.buttons["Save"].tap()
        XCTAssertFalse(field.waitForExistence(timeout: 2))
    }
}
