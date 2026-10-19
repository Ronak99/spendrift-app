//
//  HomeSpendCharts.swift
//  Spendrift
//
//  The breakdown charts on Home. They use the same enamel, ink, and hairline
//  language as the rest of the pane, and they cover what used to live only
//  on the analytics sheet: the category split, each day's spend, and the week.
//

import SwiftUI

/// Which picture of the category split the user is looking at.
enum BreakdownChart: String, CaseIterable, Identifiable {
    case stack
    case donut

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .stack: "rectangle.split.3x1"
        case .donut: "chart.pie.fill"
        }
    }

    var label: String {
        switch self {
        case .stack: "Stacked bar"
        case .donut: "Donut"
        }
    }
}

/// One wedge of the month's spend. `category` is nil for money with no category.
struct HomeSpendSlice: Identifiable {
    let id: String
    let name: String
    let amount: Double
    let color: Color
    let category: TransactionCategory?
}

enum HomeSpendChartData {
    /// Categories largest first, plus uncategorized spend when the month has any.
    static func slices(from stats: MonthSpendStats) -> [HomeSpendSlice] {
        var slices = stats.categorySpend.map { slice in
            HomeSpendSlice(
                id: slice.id.uuidString,
                name: slice.category.name,
                amount: slice.amount,
                color: CategoryEnamel.color(for: slice.category),
                category: slice.category
            )
        }
        let other = uncategorizedAmount(stats)
        if other > 0.009 {
            slices.append(
                HomeSpendSlice(
                    id: "uncategorized",
                    name: "Uncategorized",
                    amount: other,
                    color: CategoryEnamel.uncategorized,
                    category: nil
                )
            )
            slices.sort { $0.amount > $1.amount }
        }
        return slices
    }

    static func uncategorizedAmount(_ stats: MonthSpendStats) -> Double {
        let categorized = stats.categorySpend.reduce(0) { $0 + $1.amount }
        return max(0, stats.spent - categorized)
    }
}

/// Two icons beside the section title. The choice sticks, so the next visit opens the same picture.
struct BreakdownChartToggle: View {
    @Binding var selection: BreakdownChart

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BreakdownChart.allCases) { chart in
                let isSelected = selection == chart
                Button {
                    selection = chart
                } label: {
                    Image(systemName: chart.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.ink : AppTheme.inkTertiary)
                        .frame(width: 28, height: 28)
                        .background(
                            isSelected ? AppTheme.cardAlternate : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chart.label)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(2)
        .background(AppTheme.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Breakdown chart")
    }
}

/// Shares as one bar. The 2pt gaps keep neighbouring category colours from reading as one block.
struct CategoryShareBar: View {
    let slices: [HomeSpendSlice]

    var body: some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(0, slices.count - 1)) * 2
            let usable = max(0, geo.size.width - gaps)
            let total = slices.reduce(0) { $0 + $1.amount }
            HStack(spacing: 2) {
                ForEach(slices) { slice in
                    let share = total > 0 ? slice.amount / total : 0
                    Rectangle()
                        .fill(slice.color)
                        .frame(width: max(1, usable * CGFloat(share)))
                }
            }
        }
        .frame(height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.top, 16)
        .padding(.bottom, 8)
        .accessibilityHidden(true)
    }
}

/// Category split as a ring, in the same enamel and the same 14pt weight and 2pt gaps as the share bar.
struct CategorySpendDonut: View {
    let slices: [HomeSpendSlice]
    let spent: Double

    private let ring: CGFloat = 14
    private let diameter: CGFloat = 168
    private let gap: CGFloat = 2

    var body: some View {
        ZStack {
            Canvas { context, size in
                let total = slices.reduce(0) { $0 + $1.amount }
                guard total > 0 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = (min(size.width, size.height) - ring) / 2
                guard radius > 0 else { return }

                if slices.count == 1, let only = slices.first {
                    ring(in: context, center: center, radius: radius, color: only.color)
                    return
                }

                let gapAngle = Double(gap / radius)
                let sweepBudget = (2 * Double.pi) - gapAngle * Double(slices.count)
                var cursor = -Double.pi / 2

                for slice in slices {
                    let sweep = sweepBudget * (slice.amount / total)
                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .radians(cursor),
                        endAngle: .radians(cursor + sweep),
                        clockwise: false
                    )
                    context.stroke(
                        path,
                        with: .color(slice.color),
                        style: StrokeStyle(lineWidth: ring, lineCap: .butt)
                    )
                    cursor += sweep + gapAngle
                }
            }

            VStack(spacing: 1) {
                Text(spent.formatCurrencyRounded)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.4)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("spent")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.inkSecondary)
            }
            .frame(maxWidth: diameter - ring * 2 - 16)
        }
        .frame(width: diameter, height: diameter)
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spending by category")
        .accessibilityValue(spent.formatCurrencyRounded)
    }

    /// A full turn. `addArc` drops a sweep of exactly one circle, so one category
    /// is drawn as a closed ring instead.
    private func ring(in context: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: ring)
        )
    }
}

/// Each day's spend, not the running total the hero already draws.
/// Ink line, fading fill, and a dashed average, the same marks as that curve.
struct DailySpendPlot: View {
    let stats: MonthSpendStats

    private let chartHeight: CGFloat = 112
    private let topInset: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            caption
            chart
            axis
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var caption: some View {
        HStack(spacing: 12) {
            Text("Avg \(stats.dailyAverage.formatCurrencyRounded)")
            Spacer(minLength: 8)
            if let peak = stats.biggestDay {
                Text("Peak \(peakDate(peak.day)) · \(peak.amount.formatCurrencyRounded)")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(AppTheme.inkSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var chart: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = chartHeight
            let peak = stats.biggestDay?.amount ?? 0
            let scale = max(peak, 1)
            let points = elapsedPoints(width: width, height: height, scale: scale)

            ZStack(alignment: .topLeading) {
                if stats.dailyAverage > 0 {
                    Path { path in
                        let y = yValue(stats.dailyAverage, height: height, scale: scale)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(AppTheme.inkTertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                areaPath(points, height: height)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.ink.opacity(0.16), AppTheme.ink.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                linePath(points)
                    .stroke(
                        AppTheme.ink,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                    )

                if let peakDay = stats.biggestDay, let point = points.first(where: { $0.day == peakDay.day }) {
                    Circle()
                        .fill(AppTheme.ink)
                        .frame(width: 6, height: 6)
                        .position(point.point)
                }
            }
        }
        .frame(height: chartHeight)
        .drawingGroup(opaque: false)
    }

    private var axis: some View {
        let shortMonth = HomeInsights.shortMonthName(stats.month)
        return HStack {
            Text("\(shortMonth) 1")
            Spacer(minLength: 8)
            Text("\(shortMonth) \(stats.days)")
        }
        .font(.system(size: 10))
        .foregroundStyle(AppTheme.inkTertiary)
    }

    private var accessibilityText: String {
        var text = "Daily spending, average \(stats.dailyAverage.formatCurrencyRounded)"
        if let peak = stats.biggestDay {
            text += ", peak \(peakDate(peak.day)) \(peak.amount.formatCurrencyRounded)"
        }
        return text
    }

    private func peakDate(_ day: Int) -> String {
        let date = Calendar.current.date(
            from: DateComponents(year: stats.year, month: stats.month, day: day)
        ) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func yValue(_ value: Double, height: CGFloat, scale: Double) -> CGFloat {
        height - (height - topInset) * CGFloat(value / scale)
    }

    private func elapsedPoints(width: CGFloat, height: CGFloat, scale: Double) -> [(day: Int, point: CGPoint)] {
        guard stats.elapsed >= 1 else { return [] }
        let days = CGFloat(max(1, stats.days))
        return (1...stats.elapsed).map { day in
            let point = CGPoint(
                x: width * CGFloat(day) / days,
                y: yValue(stats.byDay[day], height: height, scale: scale)
            )
            return (day, point)
        }
    }

    private func linePath(_ points: [(day: Int, point: CGPoint)]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first.point)
            for entry in points.dropFirst() {
                path.addLine(to: entry.point)
            }
        }
    }

    private func areaPath(_ points: [(day: Int, point: CGPoint)], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last, points.count > 1 else { return }
            path.move(to: first.point)
            for entry in points.dropFirst() {
                path.addLine(to: entry.point)
            }
            path.addLine(to: CGPoint(x: last.point.x, y: height))
            path.addLine(to: CGPoint(x: first.point.x, y: height))
            path.closeSubpath()
        }
    }
}

/// Spend per weekday. The heaviest day is solid ink; the rest stay quiet, so the answer reads first.
struct WeekdaySpendBars: View {
    let stats: MonthSpendStats

    private let barMaxHeight: CGFloat = 72

    var body: some View {
        let days = bars
        let peak = days.first { $0.isPeak }

        return VStack(alignment: .leading, spacing: 12) {
            if let peak {
                Text("\(peak.fullName) · \(peak.amount.formatCurrencyRounded)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .lineLimit(1)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 5,
                            bottomLeadingRadius: 2,
                            bottomTrailingRadius: 2,
                            topTrailingRadius: 5,
                            style: .continuous
                        )
                        .fill(day.isPeak ? AppTheme.ink : AppTheme.ink.opacity(day.amount > 0 ? 0.22 : 0.1))
                        .frame(height: barHeight(day.amount, peak: peak?.amount ?? 0))

                        Text(day.label)
                            .font(.system(size: 10, weight: day.isPeak ? .semibold : .regular))
                            .foregroundStyle(day.isPeak ? AppTheme.ink : AppTheme.inkTertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(peak: peak))
    }

    private func accessibilityText(peak: WeekdayBar?) -> String {
        guard let peak else { return "Weekday spending" }
        return "Weekday spending, \(peak.fullName) is highest at \(peak.amount.formatCurrencyRounded)"
    }

    private func barHeight(_ amount: Double, peak: Double) -> CGFloat {
        guard peak > 0, amount > 0 else { return 3 }
        return max(3, barMaxHeight * CGFloat(amount / peak))
    }

    private var bars: [WeekdayBar] {
        let calendar = Calendar.current
        let short = calendar.shortWeekdaySymbols
        let full = calendar.weekdaySymbols
        let order = Array(calendar.firstWeekday...7) + Array(1..<calendar.firstWeekday)
        let amounts = order.map { weekday -> Double in
            let index = weekday - 1
            guard stats.byWeekday.indices.contains(index) else { return 0 }
            return stats.byWeekday[index]
        }
        let peakAmount = amounts.max() ?? 0
        var peakTaken = false

        return zip(order, amounts).map { weekday, amount in
            let index = weekday - 1
            let isPeak = !peakTaken && peakAmount > 0 && amount == peakAmount
            if isPeak { peakTaken = true }
            return WeekdayBar(
                id: weekday,
                label: short.indices.contains(index) ? short[index] : "",
                fullName: full.indices.contains(index) ? full[index] : "",
                amount: amount,
                isPeak: isPeak
            )
        }
    }
}

private struct WeekdayBar: Identifiable {
    let id: Int
    let label: String
    let fullName: String
    let amount: Double
    let isPeak: Bool
}
