//
//  CapsuleDateSelector.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

// MARK: - Liquid Glass surfaces

/// Groups the floating chrome so nearby glass surfaces sample and blend as one
/// layer instead of stacking two independent ones. Plain passthrough before iOS 26.
private struct GlassGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

private extension View {
    /// Liquid Glass capsule on iOS 26, falling back to the flat raised surface
    /// fill everywhere else.
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(Capsule().fill(AppTheme.listGroupBackground))
        }
    }

    /// Liquid Glass rounded card on iOS 26, falling back to the flat grey fill.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

struct CapsuleDateSelector: View {
    @Binding var period: TransactionPeriod
    let title: String
    let date: Date
    let isCurrentPeriod: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    var onToday: (() -> Void)? = nil
    var onJumpToDate: ((Date) -> Void)? = nil

    @AppStorage("hasSeenCapsuleGestureHint") private var hasSeenHint = false
    @State private var showJumpSheet = false
    @State private var isPressing = false
    @State private var showGestureHint = false

    var body: some View {
        GlassGroup(spacing: 8) {
            VStack(spacing: 8) {
                HStack {
                    periodMenuButton

                    Spacer().frame(width: 16)

                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer(minLength: 0)

                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .scaleEffect(isPressing ? 0.94 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressing)
                        .onTapGesture(count: 2) {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onToday?()
                        }
                        .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                            isPressing = pressing
                            if pressing { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                        }, perform: {
                            isPressing = false
                            showJumpSheet = true
                        })

                    Spacer(minLength: 0)

                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer().frame(width: 16)

                    // Balances the leading period menu so the title stays centred.
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.headline)
                        .hidden()
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .glassCapsule()

                if showGestureHint {
                    GestureHintTooltip(period: period)
                        .transition(
                            .asymmetric(
                                insertion: .push(from: .top).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) { showGestureHint = false }
                        }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: showGestureHint)
        .onChange(of: date) { _, _ in
            guard !hasSeenHint else { return }
            guard !isCurrentPeriod else { return }
            hasSeenHint = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { showGestureHint = true }
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation(.easeOut(duration: 0.25)) { showGestureHint = false }
            }
        }
        .sheet(isPresented: $showJumpSheet) {
            jumpSheetContent
        }
    }

    private var periodMenuButton: some View {
        Menu {
            ForEach(TransactionPeriod.allCases) { option in
                Button {
                    period = option
                } label: {
                    HStack {
                        Text(option.label)
                        Spacer(minLength: 12)
                        if period == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.headline)
                .foregroundColor(.primary)
                .opacity(0.5)
        }
        .accessibilityLabel("Time range")
    }

    @ViewBuilder
    private var jumpSheetContent: some View {
        switch period {
        case .week:
            WeekJumpSheet(
                initialDate: date,
                onSelect: { picked in
                    onJumpToDate?(picked)
                }
            )
        case .month, .threeMonths, .sixMonths:
            MonthYearPickerSheet(date: date) { picked in
                onJumpToDate?(picked)
            }
        case .year:
            YearPickerSheet(initialDate: date) { picked in
                onJumpToDate?(picked)
            }
        }
    }
}

// MARK: - Week jump

private struct WeekJumpSheet: View {
    let initialDate: Date
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Date

    init(initialDate: Date, onSelect: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onSelect = onSelect
        _picked = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Choose a week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DatePicker(
                    "",
                    selection: $picked,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Jump to week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                CustomSheetCloseToolbarItem()
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Go") {
                        onSelect(picked)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

// MARK: - Month/Year Picker Sheet

private struct MonthYearPickerSheet: View {
    let initialDate: Date
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayYear: Int

    private let calendar = Calendar.current
    private let shortMonths = Calendar.current.shortMonthSymbols

    init(date: Date, onSelect: @escaping (Date) -> Void) {
        self.initialDate = date
        self.onSelect = onSelect
        _displayYear = State(initialValue: Calendar.current.component(.year, from: date))
    }

    private var selectedMonth: Int { calendar.component(.month, from: initialDate) }
    private var selectedYear: Int  { calendar.component(.year, from: initialDate) }
    private var currentMonth: Int  { calendar.component(.month, from: Date()) }
    private var currentYear: Int   { calendar.component(.year, from: Date()) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                HStack {
                    Button {
                        displayYear -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Text(String(displayYear))
                        .font(.title2.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy, value: displayYear)

                    Spacer()

                    Button {
                        displayYear += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                    spacing: 12
                ) {
                    ForEach(1...12, id: \.self) { month in
                        Button {
                            selectMonth(month)
                        } label: {
                            Text(shortMonths[month - 1])
                                .font(.callout.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(tileBackground(month: month))
                                .foregroundColor(tileForeground(month: month))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isFuture(month: month))
                        .opacity(isFuture(month: month) ? 0.35 : 1)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Jump to month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    private func selectMonth(_ month: Int) {
        var comps = DateComponents()
        comps.year = displayYear
        comps.month = month
        comps.day = 1
        if let date = calendar.date(from: comps) {
            onSelect(date)
            dismiss()
        }
    }

    private func isFuture(month: Int) -> Bool {
        guard displayYear == currentYear else { return displayYear > currentYear }
        return month > currentMonth
    }

    private func tileBackground(month: Int) -> Color {
        if month == selectedMonth && displayYear == selectedYear {
            return .blue
        } else if month == currentMonth && displayYear == currentYear {
            return Color(.systemGray4)
        }
        return Color(.systemGray6)
    }

    private func tileForeground(month: Int) -> Color {
        month == selectedMonth && displayYear == selectedYear ? .white : .primary
    }
}

// MARK: - Year picker

private struct YearPickerSheet: View {
    let initialDate: Date
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current
    private var currentYear: Int { calendar.component(.year, from: Date()) }
    private var selectedYear: Int { calendar.component(.year, from: initialDate) }

    private var years: [Int] {
        let low = min(2015, selectedYear)
        let high = max(currentYear + 1, selectedYear)
        guard low <= high else { return [selectedYear] }
        return Array(low...high)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 12)], spacing: 12) {
                    ForEach(years.reversed(), id: \.self) { year in
                        Button {
                            selectYear(year)
                        } label: {
                            Text(String(year))
                                .font(.callout.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(tileBackground(year: year))
                                .foregroundColor(tileForeground(year: year))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(year > currentYear)
                        .opacity(year > currentYear ? 0.35 : 1)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .navigationTitle("Jump to year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    private func selectYear(_ year: Int) {
        var comps = DateComponents()
        comps.year = year
        comps.month = 1
        comps.day = 1
        if let date = calendar.date(from: comps) {
            onSelect(date)
            dismiss()
        }
    }

    private func tileBackground(year: Int) -> Color {
        if year == selectedYear {
            return .blue
        } else if year == currentYear {
            return Color(.systemGray4)
        }
        return Color(.systemGray6)
    }

    private func tileForeground(year: Int) -> Color {
        year == selectedYear ? .white : .primary
    }
}

// MARK: - Gesture Hint Tooltip

private struct GestureHintTooltip: View {
    let period: TransactionPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(doubleTapLabel, systemImage: "hand.tap")
            Label(longPressLabel, systemImage: "calendar")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
    }

    private var doubleTapLabel: String {
        switch period {
        case .week: return "Double tap to jump to this week"
        case .month: return "Double tap to return to today’s month"
        case .threeMonths, .sixMonths: return "Double tap to return to the current range"
        case .year: return "Double tap to jump to this year"
        }
    }

    private var longPressLabel: String {
        switch period {
        case .week: return "Long press to pick a week"
        case .month: return "Long press to jump to any month"
        case .threeMonths, .sixMonths: return "Long press to choose the ending month"
        case .year: return "Long press to pick a year"
        }
    }
}

#Preview {
    @Previewable @State var period = TransactionPeriod.month

    CapsuleDateSelector(
        period: $period,
        title: "April 2026",
        date: Date(),
        isCurrentPeriod: true,
        onPrevious: {},
        onNext: {},
        onToday: {},
        onJumpToDate: { _ in }
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
        // Glass only reads against something; mirror the ledger wash behind it.
        LinearGradient(
            colors: [AppTheme.atmosphere.opacity(0.55), AppTheme.listBackground],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
