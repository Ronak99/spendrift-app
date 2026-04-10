//
//  CapsuleDateSelector.swift
//  Spendrift
//
//  Created by Ronak Punase on 25/02/26.
//

import SwiftUI

struct CapsuleDateSelector: View {
    let date: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    var onToday: (() -> Void)? = nil
    var onDateSelected: ((Date) -> Void)? = nil

    @AppStorage("hasSeenCapsuleGestureHint") private var hasSeenHint = false
    @State private var showMonthPicker = false
    @State private var isPressing = false
    @State private var showGestureHint = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(date.monthYear)
                    .font(.headline)
                    .fontWeight(.semibold)
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
                        showMonthPicker = true
                    })

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )

            if showGestureHint {
                GestureHintTooltip()
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
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: showGestureHint)
        .onChange(of: date) { _, newDate in
            guard !hasSeenHint else { return }
            guard !Calendar.current.isDate(newDate, equalTo: Date(), toGranularity: .month) else { return }
            hasSeenHint = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { showGestureHint = true }
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation(.easeOut(duration: 0.25)) { showGestureHint = false }
            }
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthYearPickerSheet(date: date) { picked in
                onDateSelected?(picked)
            }
        }
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
                // Year navigation
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

                // Month grid
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
            .navigationTitle("Jump to Month")
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

// MARK: - Gesture Hint Tooltip

private struct GestureHintTooltip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Double tap to return to today", systemImage: "hand.tap")
            Label("Long press to jump to any month", systemImage: "calendar")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    CapsuleDateSelector(
        date: Date(),
        onPrevious: {},
        onNext: {},
        onToday: {},
        onDateSelected: { _ in }
    )
    .padding()
}
