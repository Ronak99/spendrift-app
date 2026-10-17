//
//  HomeAnalyticsPane.swift
//  Spendrift
//
//  Home is analytics. The hero carries the month's spend and its curve, then four
//  blocks answer: who am I this month, am I okay, where did it go, what just happened.
//  Every block recomputes for the month picked in the hero.
//

import SwiftUI

struct HomeAnalyticsPane: View {
    /// Whole ledger, newest first. Blocks slice the month they need out of it.
    let transactions: [Transaction]
    let categories: [TransactionCategory]
    @Binding var month: MonthRef
    /// Whole-month cap, or zero when none is set.
    let totalBudget: Double
    let today: Date

    var onPickMonth: () -> Void
    var onEditTotalBudget: () -> Void
    var onAddCategoryBudget: () -> Void
    var onOpenCategory: (TransactionCategory) -> Void
    var onOpenTransaction: (Transaction) -> Void
    var onOpenTab: (HomeTab) -> Void
    var onAddTransaction: () -> Void
    /// Opens the full analytics for the picked month: charts, drills, the lot.
    var onOpenAnalytics: () -> Void
    var onScroll: (CGFloat) -> Void

    var body: some View {
        let stats = month.stats(from: transactions, today: today)
        let previous = month.previous.stats(from: transactions, today: today)
        let capped = MonthlyBudget.capped(in: categories, month: stats)
        let insights = HomeInsights.rows(
            month: stats,
            previous: previous,
            capped: capped,
            allTransactions: transactions,
            today: today
        )

        return ScrollView {
            VStack(spacing: 26) {
                hero(stats)
                personaBlock(stats)
                tiles(stats, previous: previous)
                budgetsBlock(capped)
                if !insights.isEmpty {
                    insightsBlock(insights)
                }
                breakdown(stats, previous: previous)
                recentBlock()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
        }
        .scrollIndicators(.hidden)
        .homeTrayClearance()
        .reportingScrollOffset(onScroll)
    }

    // MARK: Hero

    private func hero(_ stats: MonthSpendStats) -> some View {
        VStack(spacing: 0) {
            Button(action: onPickMonth) {
                HStack(spacing: 4) {
                    Text("Total spent in \(month.title(relativeTo: today))")
                        .font(.system(size: 17))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppTheme.inkSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(HomePressStyle(scale: 1))
            .accessibilityLabel("Change month")
            .accessibilityValue(month.title(relativeTo: today))

            Text(stats.spent.formatCurrencyRounded)
                .font(.system(size: 56, weight: .semibold))
                .tracking(-2)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 4)

            HStack(spacing: 14) {
                heroFigure("Income", stats.income, tint: AppTheme.income)
                heroFigure("Saved", stats.saved, tint: stats.saved >= 0 ? AppTheme.income : AppTheme.expense)
            }
            .padding(.top, 10)

            if totalBudget == 0 {
                Button(action: onEditTotalBudget) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Set a monthly budget")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(AppTheme.inkSecondary)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HomePressStyle(scale: 1))
            }

            HeroSpendPlot(month: stats, cap: totalBudget, onEditBudget: onEditTotalBudget)
                .padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        // The curve bleeds past the pane's gutters, the way Expensa's does.
        .padding(.horizontal, -16)
    }

    private func heroFigure(_ caption: String, _ value: Double, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(caption)
                .foregroundStyle(AppTheme.inkSecondary)
            Text(value.formatCurrencyRounded)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .font(.system(size: 13))
    }

    // MARK: Persona

    private func personaBlock(_ stats: MonthSpendStats) -> some View {
        Group {
            if let persona = HomeInsights.persona(for: stats) {
                Button {
                    onOpenCategory(persona.category)
                } label: {
                    personaCard(persona, stats: stats)
                }
                .buttonStyle(HomePressStyle())
            } else {
                personaEmpty
            }
        }
    }

    private func personaCard(_ persona: SpendPersona, stats: MonthSpendStats) -> some View {
        HStack(spacing: 14) {
            EnamelBadge(
                systemImage: persona.category.icon.systemImageName,
                color: CategoryEnamel.color(for: persona.category),
                side: 50,
                showsShadow: true
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(stats.isCurrent ? "This month you are" : "In \(month.name) you were")
                    .font(.system(size: 12))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.inkSecondary)
                Text(persona.label)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                Text(persona.reason)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.inkTertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your spending persona, \(persona.label)")
    }

    private var personaEmpty: some View {
        HStack(spacing: 14) {
            EnamelBadge(systemImage: "tray.fill", color: CategoryEnamel.uncategorized, side: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(month.title(relativeTo: today))
                    .font(.system(size: 12))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.inkSecondary)
                Text("Nothing spent yet")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                Text("Add a transaction and a persona appears.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: Tiles

    private func tiles(_ stats: MonthSpendStats, previous: MonthSpendStats) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return LazyVGrid(columns: columns, spacing: 10) {
            HomeStatTile(
                caption: "Daily average",
                value: stats.dailyAverage.formatCurrencyRounded,
                detail: deltaText(
                    current: stats.dailyAverage,
                    previous: previous.dailyAverage,
                    suffix: previous.month == stats.month ? "last month" : HomeInsights.monthName(previous.month)
                )
            )

            if stats.isCurrent {
                paceTile(stats)
                safeToSpendTile(stats)
            } else {
                ofIncomeTile(stats)
                biggestDayTile(stats)
            }

            HomeStatTile(
                caption: "No-spend days",
                value: "\(stats.noSpendDays)",
                valueSuffix: "of \(stats.elapsed)",
                detail: Text("best streak \(stats.bestNoSpendStreak) day\(stats.bestNoSpendStreak == 1 ? "" : "s")")
            )
        }
    }

    /// Ceiling the forward-looking tiles measure against: the budget when one is set,
    /// the month's income otherwise.
    private func ceiling(_ stats: MonthSpendStats) -> (value: Double, word: String) {
        totalBudget > 0 ? (totalBudget, "budget") : (stats.income, "income")
    }

    private func paceTile(_ stats: MonthSpendStats) -> some View {
        let pace = stats.projectedTotal
        let limit = ceiling(stats)
        let detail: Text = pace <= limit.value
            ? Text("\((limit.value - pace).formatCurrencyRounded) under \(limit.word)")
            : Text("\((pace - limit.value).formatCurrencyRounded) over \(limit.word)")
                .foregroundColor(AppTheme.expense)

        return HomeStatTile(
            caption: "On pace for",
            value: pace.formatCurrencyRounded,
            detail: detail
        )
    }

    private func safeToSpendTile(_ stats: MonthSpendStats) -> some View {
        let limit = ceiling(stats)
        let left = stats.daysLeft
        let safe = left > 0 ? max(0, limit.value - stats.spent) / Double(left) : 0
        let detail: Text = stats.spent > limit.value
            ? Text("\(limit.word) already spent").foregroundColor(AppTheme.expense)
            : Text("of \(limit.word), \(left) day\(left == 1 ? "" : "s") left")

        return HomeStatTile(
            caption: "Safe to spend",
            value: safe.formatCurrencyRounded,
            valueSuffix: "/day",
            detail: detail
        )
    }

    private func ofIncomeTile(_ stats: MonthSpendStats) -> some View {
        let share = stats.income > 0 ? Int((stats.spent / stats.income * 100).rounded()) : 0
        return HomeStatTile(
            caption: "Of income",
            value: "\(share)",
            valueSuffix: "%",
            detail: Text("\(stats.saved.formatCurrencyRounded) saved")
        )
    }

    private func biggestDayTile(_ stats: MonthSpendStats) -> some View {
        guard let biggest = stats.biggestDay else {
            return HomeStatTile(
                caption: "Biggest day",
                value: 0.0.formatCurrencyRounded,
                detail: Text("nothing spent")
            )
        }
        let date = Calendar.current.date(
            from: DateComponents(year: stats.year, month: stats.month, day: biggest.day)
        ) ?? today
        return HomeStatTile(
            caption: "Biggest day",
            value: biggest.amount.formatCurrencyRounded,
            detail: Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        )
    }

    private func deltaText(current: Double, previous: Double, suffix: String) -> Text {
        guard let change = MonthSpendStats.change(from: previous, to: current) else {
            return Text("")
        }
        if change == 0 {
            return Text("same as \(suffix)")
        }
        let arrow = change > 0 ? "↑" : "↓"
        return Text("\(arrow) \(abs(change))%")
            .foregroundColor(change > 0 ? AppTheme.expense : AppTheme.income)
            + Text(" vs \(suffix)")
    }

    // MARK: Budgets

    private func budgetsBlock(_ capped: [CappedCategory]) -> some View {
        VStack(spacing: 10) {
            HomeSectionHeader(title: "Budgets", showsChevron: true) {
                onOpenTab(.categories)
            }

            HomeCard {
                if capped.isEmpty, totalBudget == 0 {
                    budgetsInvitation
                } else {
                    ForEach(Array(capped.enumerated()), id: \.element.id) { index, budget in
                        if index > 0 {
                            HomeRowDivider()
                        }
                        budgetRow(budget)
                    }
                    HomeCardLink(title: "Add a category budget", action: onAddCategoryBudget)
                }
            }
        }
    }

    private var budgetsInvitation: some View {
        HStack(spacing: 14) {
            EnamelBadge(systemImage: "chart.line.uptrend.xyaxis", color: CategoryEnamel.uncategorized)
            VStack(alignment: .leading, spacing: 2) {
                Text("No budgets yet")
                    .font(.system(size: 15, weight: .semibold))
                Text("Cap the whole month, or one category at a time.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onEditTotalBudget) {
                Text("Set one")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(AppTheme.actionBackground, in: Capsule())
                    .foregroundStyle(AppTheme.actionForeground)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private func budgetRow(_ budget: CappedCategory) -> some View {
        Button {
            onOpenCategory(budget.category)
        } label: {
            HStack(spacing: 12) {
                EnamelBadge(
                    systemImage: budget.category.icon.systemImageName,
                    color: CategoryEnamel.color(for: budget.category)
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text(budget.category.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    BudgetBar(
                        spent: budget.spent,
                        cap: budget.cap,
                        color: CategoryEnamel.color(for: budget.category)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(
                        budget.isOver
                            ? "\((-budget.remaining).formatCurrencyRounded) over"
                            : "\(budget.remaining.formatCurrencyRounded) left"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(budget.isOver ? AppTheme.expense : AppTheme.ink)
                    Text("\(budget.spent.formatCurrencyRounded) of \(budget.cap.formatCurrencyRounded)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AppTheme.inkSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: Insights

    private func insightsBlock(_ insights: [SpendInsight]) -> some View {
        VStack(spacing: 10) {
            HomeSectionHeader(title: "Insights")
            HomeCard {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    if index > 0 {
                        HomeRowDivider()
                    }
                    insightRow(insight)
                }
            }
        }
    }

    private func insightRow(_ insight: SpendInsight) -> some View {
        HStack(spacing: 14) {
            Image(systemName: insight.symbol)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 34, height: 34)
                .background(AppTheme.cardAlternate, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 14.5))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = insight.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Where it went

    private func breakdown(_ stats: MonthSpendStats, previous: MonthSpendStats) -> some View {
        VStack(spacing: 10) {
            HomeSectionHeader(title: "Where it went", showsChevron: true, action: onOpenAnalytics)
            HomeCard {
                if stats.categorySpend.isEmpty {
                    Text("Nothing spent in \(month.name)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.inkSecondary)
                        .padding(.vertical, 12)
                } else {
                    stackedBar(stats)
                    ForEach(Array(stats.categorySpend.prefix(4).enumerated()), id: \.element.id) { index, slice in
                        if index > 0 {
                            HomeRowDivider()
                        }
                        breakdownRow(slice, stats: stats, previous: previous)
                    }
                }
                HomeCardLink(title: "All categories") { onOpenTab(.categories) }
            }
        }
    }

    /// Shares as one bar. The 2pt gaps keep neighbouring category colours from
    /// reading as one block, and the labelled rows below carry the identity.
    private func stackedBar(_ stats: MonthSpendStats) -> some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(0, stats.categorySpend.count - 1)) * 2
            let usable = max(0, geo.size.width - gaps)
            HStack(spacing: 2) {
                ForEach(stats.categorySpend) { slice in
                    Rectangle()
                        .fill(CategoryEnamel.color(for: slice.category))
                        .frame(width: max(1, usable * CGFloat(stats.share(of: slice.amount))))
                }
            }
        }
        .frame(height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }

    private func breakdownRow(
        _ slice: MonthSpendStats.CategorySpend,
        stats: MonthSpendStats,
        previous: MonthSpendStats
    ) -> some View {
        let cap = MonthlyBudget.cap(for: slice.category)
        let color = CategoryEnamel.color(for: slice.category)
        let change = MonthSpendStats.change(from: previous.spent(in: slice.category), to: slice.amount)

        return Button {
            onOpenCategory(slice.category)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 6) {
                    Text(slice.category.name)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    if cap > 0 {
                        BudgetBar(spent: slice.amount, cap: cap, color: color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(Int((stats.share(of: slice.amount) * 100).rounded()))%")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .frame(width: 36, alignment: .trailing)

                Text(slice.amount.formatCurrencyRounded)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 76, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                deltaBadge(change)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityElement(children: .combine)
    }

    private func deltaBadge(_ change: Int?) -> some View {
        Group {
            switch change {
            case .none:
                Text("new").foregroundStyle(AppTheme.inkTertiary)
            case .some(0):
                Text("same").foregroundStyle(AppTheme.inkTertiary)
            case .some(let value):
                Text("\(value > 0 ? "↑" : "↓")\(abs(value))%")
                    .foregroundStyle(value > 0 ? AppTheme.expense : AppTheme.income)
            }
        }
        .font(.system(size: 12))
        .lineLimit(1)
    }

    // MARK: Recent

    private func recentBlock() -> some View {
        let recent = Array(transactions.filter(\.isPersisted).prefix(3))

        return VStack(spacing: 10) {
            HomeSectionHeader(title: "Recent")
            HomeCard {
                if recent.isEmpty {
                    Button(action: onAddTransaction) {
                        HStack(spacing: 14) {
                            CreateSlotEnamel(side: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add your first transaction")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("It shows up here, and in every total above")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.inkSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HomePressStyle(scale: 1))
                } else {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, transaction in
                        if index > 0 {
                            HomeRowDivider()
                        }
                        Button {
                            onOpenTransaction(transaction)
                        } label: {
                            TransactionListItem(transaction: transaction, dateStyle: .relative)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(HomePressStyle(scale: 1))
                    }
                    HomeCardLink(title: "All transactions") { onOpenTab(.transactions) }
                }
            }
        }
    }
}
