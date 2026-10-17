//
//  HeroSpendPlot.swift
//  Spendrift
//
//  The month's cumulative spend, bleeding to both edges with no card around it.
//  A dotted line marks the budget, a dashed tail projects today's pace to the end
//  of the month, and a red dot marks where the two meet.
//

import SwiftUI

struct HeroSpendPlot: View {
    let month: MonthSpendStats
    let cap: Double
    /// Tapping the budget label edits the monthly cap.
    let onEditBudget: () -> Void

    private let chartHeight: CGFloat = 120
    private let legendHeight: CGFloat = 26
    /// Headroom above the tallest value so the curve never touches the top edge.
    private let topInset: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let model = HeroChartModel(
                month: month,
                cap: cap,
                width: geo.size.width,
                height: chartHeight,
                topInset: topInset
            )

            ZStack(alignment: .topLeading) {
                chart(model)
                    .frame(width: geo.size.width, height: chartHeight)

                if cap > 0 {
                    budgetLabel
                        .offset(x: 16, y: max(0, model.y(for: cap) - 17))
                }

                legend(model)
                    .frame(width: geo.size.width, height: legendHeight)
                    .offset(y: chartHeight + 6)
            }
        }
        .frame(height: chartHeight + legendHeight + 6)
        .accessibilityElement(children: .contain)
    }

    // MARK: Curve

    private func chart(_ model: HeroChartModel) -> some View {
        ZStack(alignment: .topLeading) {
            model.areaPath
                .fill(
                    LinearGradient(
                        colors: [AppTheme.ink.opacity(0.16), AppTheme.ink.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if cap > 0 {
                Path { path in
                    let y = model.y(for: cap)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: model.width, y: y))
                }
                .stroke(
                    AppTheme.inkTertiary,
                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 4])
                )
            }

            if let projection = model.projectionPath {
                projection
                    .stroke(
                        AppTheme.inkTertiary,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                    )
            }

            model.linePath
                .stroke(
                    AppTheme.ink,
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )

            if let crossing = model.crossing {
                Circle()
                    .fill(AppTheme.expense)
                    .frame(width: 7, height: 7)
                    .position(x: crossing.x, y: model.y(for: cap))
            }
        }
        .drawingGroup(opaque: false)
    }

    private var budgetLabel: some View {
        Button(action: onEditBudget) {
            Text("Budget \(cap.formatCurrencyRounded)")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.inkSecondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 1))
        .accessibilityLabel("Edit monthly budget")
        .accessibilityValue(cap.formatCurrencyRounded)
    }

    // MARK: Legend

    private func legend(_ model: HeroChartModel) -> some View {
        let shortMonth = HomeInsights.shortMonthName(month.month)

        return ZStack(alignment: .topLeading) {
            HStack {
                Text("\(shortMonth) 1")
                Spacer(minLength: 8)
                Text("\(shortMonth) \(month.days)")
            }
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.inkTertiary)
            .padding(.horizontal, 16)

            if let crossing = model.crossing {
                Text(crossing.label)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.expense)
                    .fixedSize()
                    .position(x: model.clampedLabelX(crossing.x), y: 7)
            } else if month.isCurrent, let today = model.lastPoint {
                Text("Today, \(shortMonth) \(month.elapsed)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .fixedSize()
                    .position(x: model.clampedLabelX(today.x), y: 7)
            }
        }
    }
}

/// Everything geometric about the hero curve, so the chart, the budget label and
/// the legend all read the same numbers.
struct HeroChartModel {
    /// Where the curve meets the cap, and what the legend calls that day.
    struct Crossing {
        let x: CGFloat
        let label: String
    }

    let width: CGFloat
    let height: CGFloat

    private let month: MonthSpendStats
    private let cap: Double
    private let topInset: CGFloat
    /// Largest value the plot has to fit: the spend, the cap, and the projected end.
    private let scale: Double
    private let points: [CGPoint]

    init(month: MonthSpendStats, cap: Double, width: CGFloat, height: CGFloat, topInset: CGFloat) {
        self.month = month
        self.cap = cap
        self.width = width
        self.height = height
        self.topInset = topInset

        let projected = month.isCurrent ? month.projectedTotal : 0
        self.scale = max(max(month.spent, cap), projected) > 0
            ? max(max(month.spent, cap), projected)
            : 1

        let days = max(1, month.days)
        let usable = height - topInset
        let scaleValue = self.scale
        func y(_ value: Double) -> CGFloat {
            height - usable * CGFloat(value / scaleValue)
        }

        var points: [CGPoint] = [CGPoint(x: 0, y: height)]
        var running = 0.0
        if month.elapsed >= 1 {
            for day in 1...month.elapsed {
                running += month.byDay[day]
                points.append(CGPoint(x: width * CGFloat(day) / CGFloat(days), y: y(running)))
            }
        }
        self.points = points
    }

    func y(for value: Double) -> CGFloat {
        height - (height - topInset) * CGFloat(value / scale)
    }

    var lastPoint: CGPoint? { points.count > 1 ? points.last : nil }

    var linePath: Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    var areaPath: Path {
        Path { path in
            guard let first = points.first, let last = points.last, points.count > 1 else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.closeSubpath()
        }
    }

    /// Dashed tail from today to the end of the month at today's pace.
    var projectionPath: Path? {
        guard month.isCurrent, let last = lastPoint else { return nil }
        return Path { path in
            path.move(to: last)
            path.addLine(to: CGPoint(x: width, y: y(for: month.projectedTotal)))
        }
    }

    var crossing: Crossing? {
        guard cap > 0 else { return nil }
        let shortMonth = HomeInsights.shortMonthName(month.month)
        let days = CGFloat(max(1, month.days))

        if month.spent > cap {
            let day = month.dayCrossing(cap) ?? month.elapsed
            let x = width * CGFloat(day) / days
            let verb = month.isCurrent ? "Over since" : "Over from"
            return Crossing(x: x, label: "\(verb) \(shortMonth) \(day)")
        }

        guard month.isCurrent, month.projectedTotal > cap, month.dailyAverage > 0 else { return nil }
        let dayReached = cap / month.dailyAverage
        let x = width * CGFloat(dayReached) / days
        return Crossing(x: x, label: "Runs out \(shortMonth) \(Int(dayReached.rounded(.up)))")
    }

    /// Keeps a centred legend label inside the plot.
    func clampedLabelX(_ x: CGFloat) -> CGFloat {
        min(max(x, 44), max(44, width - 44))
    }
}
