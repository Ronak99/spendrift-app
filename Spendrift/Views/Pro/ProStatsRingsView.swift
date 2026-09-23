//
//  ProStatsRingsView.swift
//  Spendrift
//
//  The expanded body of the "Pro Stats" settings row: this month's free-tier usage
//  for all four AI features as concentric rings, plus a legend.
//
//  One dial instead of four rows. The rings are decorative — every number they
//  encode is also written out in the legend below, which is what VoiceOver reads.
//

import SwiftUI

struct ProStatsRingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drawn on appear rather than at build time so the arcs sweep out when the
    /// row expands instead of snapping in already filled.
    @State private var isFilled = false

    private let stats = ProStat.currentMonth()

    var body: some View {
        VStack(spacing: 20) {
            rings
            legend
        }
        .padding(.top, 4)
        .onAppear { isFilled = true }
        .onDisappear { isFilled = false }
    }

    // MARK: - Rings

    private var rings: some View {
        ZStack {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                ring(for: stat, at: index)
            }
        }
        .frame(width: Self.ringSize, height: Self.ringSize)
        .accessibilityHidden(true)
    }

    private func ring(for stat: ProStat, at index: Int) -> some View {
        ZStack {
            Circle()
                .stroke(stat.color.opacity(0.22), lineWidth: Self.lineWidth)

            Circle()
                .trim(from: 0, to: isFilled ? stat.usedFraction : 0)
                .stroke(
                    stat.color,
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(fillAnimation(at: index), value: isFilled)
        }
        .frame(width: Self.diameter(at: index), height: Self.diameter(at: index))
    }

    private func fillAnimation(at index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeOut(duration: 0.85).delay(Double(index) * 0.07)
    }

    // MARK: - Legend

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(stats) { stat in
                HStack(spacing: 8) {
                    Circle()
                        .fill(stat.color)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(stat.feature.displayName)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(stat.remainingLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Geometry

    private static let ringSize: CGFloat = 208
    private static let lineWidth: CGFloat = 18
    /// Hairline gap so neighbouring rings read as separate tracks, not one band.
    private static let ringSpacing: CGFloat = 4

    private static func diameter(at index: Int) -> CGFloat {
        ringSize - CGFloat(index) * 2 * (lineWidth + ringSpacing)
    }
}

// MARK: - Model

/// One feature's month-to-date usage, paired with the ring colour it owns.
struct ProStat: Identifiable {
    let feature: ProFeature
    let used: Int
    /// This month's allowance: zero in the signup month until notifications are on.
    let quota: Int
    let color: Color

    var id: String { feature.id }
    var remaining: Int { max(0, quota - used) }

    /// Clamped: a batch import can consume the last credits, and a ring past full
    /// would wind a second time around the track.
    var usedFraction: Double {
        guard quota > 0 else { return 0 }
        return min(1, Double(used) / Double(quota))
    }

    var remainingLabel: String {
        guard quota > 0 else { return "Turn on notifications to unlock" }
        return "\(remaining) of \(quota) left"
    }

    /// Fixed hues from the app palette rather than the user's accent: four shades of
    /// one accent would be indistinguishable stacked as concentric bands.
    private static let ringColors: [Color] = [
        Color(hex: "#EC4899"),
        Color(hex: "#22C55E"),
        Color(hex: "#22C3E6"),
        Color(hex: "#9B7BFF"),
    ]

    static func currentMonth() -> [ProStat] {
        ProFeature.allCases.enumerated().map { index, feature in
            ProStat(
                feature: feature,
                used: AIQuotaStore.used(feature),
                quota: AIQuotaStore.monthlyAllowance(feature),
                color: ringColors[index % ringColors.count]
            )
        }
    }

    /// Headline percentage for the collapsed row. Each feature is weighted equally
    /// instead of pooling credits, so spending the single statement import registers
    /// as a quarter of Pro used rather than one forty-sixth.
    static func averageUsedPercent(_ stats: [ProStat]) -> Int {
        guard !stats.isEmpty else { return 0 }
        let mean = stats.reduce(0.0) { $0 + $1.usedFraction } / Double(stats.count)
        return Int((mean * 100).rounded())
    }
}

#Preview {
    List {
        Section("Spendrift Pro") {
            ProStatsRingsView()
        }
    }
}
