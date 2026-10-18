//
//  HeroSpendPlot.swift
//  Spendrift
//
//  The month's cumulative spend, bleeding to both edges with no card around it.
//  A dashed tail projects today's pace to the end of the month.
//

import SwiftUI

struct HeroSpendPlot: View {
    let month: MonthSpendStats

    private let chartHeight: CGFloat = 120
    private let legendHeight: CGFloat = 26
    /// Headroom above the tallest value so the curve never touches the top edge.
    private let topInset: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let model = HeroChartModel(
                month: month,
                width: geo.size.width,
                height: chartHeight,
                topInset: topInset
            )

            ZStack(alignment: .topLeading) {
                chart(model)
                    .frame(width: geo.size.width, height: chartHeight)

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
        }
        .drawingGroup(opaque: false)
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
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.inkTertiary)
            .padding(.horizontal, 16)

            if month.isCurrent, let today = model.lastPoint {
                Text("Today, \(shortMonth) \(month.elapsed)")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.inkSecondary)
                    .fixedSize()
                    .position(x: model.clampedLabelX(today.x), y: 7)
            }
        }
    }
}

/// Everything geometric about the hero curve, so the chart and the legend read
/// the same numbers.
struct HeroChartModel {
    let width: CGFloat
    let height: CGFloat

    private let month: MonthSpendStats
    private let topInset: CGFloat
    /// Largest value the plot has to fit: the spend and the projected end.
    private let scale: Double
    private let points: [CGPoint]

    init(month: MonthSpendStats, width: CGFloat, height: CGFloat, topInset: CGFloat) {
        self.month = month
        self.width = width
        self.height = height
        self.topInset = topInset

        let projected = month.isCurrent ? month.projectedTotal : 0
        self.scale = max(month.spent, projected) > 0 ? max(month.spent, projected) : 1

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

    /// Keeps a centred legend label inside the plot.
    func clampedLabelX(_ x: CGFloat) -> CGFloat {
        min(max(x, 44), max(44, width - 44))
    }
}
