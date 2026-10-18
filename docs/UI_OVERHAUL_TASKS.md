# UI Overhaul Tasks

Working list of tasks for the `ui-overhaul` branch.
Each task describes the intent only.
Implementation details get figured out when the task is picked up.

## Navigation and Tabs

### 2. More robust header collapse animation
- [ ] Rework the header collapse on scroll so it is smooth and predictable.
It should not jitter, jump, or get stuck halfway, including during fast scrolls, bounces, and tab switches.

### 6. New Explore tab
- [ ] Add a separate Explore tab that showcases ways to add transactions and integrations.
Items: Bank SMS, Email Receipts, Speak shortcut, Text shortcut, Siri support.

## Home and Analytics

### 16. Add a pie chart
- [x] Add a pie or donut chart for spending by category, to make the breakdown easier to visualize at a glance.

### 21. Seed categories only when none exist
- [ ] The on-appear category seeding should only run if no categories exist.
This prevents deleted default categories from coming back.
This task pairs with task 20.

## New Features

### 23. Import data from other apps
- [ ] Let users import an export file from another expense app.
The file is sent to an AI API, which returns a list of parsed transactions.
The user can then review and confirm them before they are saved.
