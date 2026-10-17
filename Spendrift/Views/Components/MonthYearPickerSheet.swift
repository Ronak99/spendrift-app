//
//  MonthYearPickerSheet.swift
//  Spendrift
//
//  Year chevrons over a 3x4 month grid. Picking a month loads it rather than
//  scrolling to it, so a jump back a year costs one tap, not a thousand rows.
//

import SwiftUI

struct MonthYearPickerSheet: View {
    /// Month the caller is looking at now.
    let selection: MonthRef
    /// Earliest year worth offering, usually the oldest transaction's.
    let earliestYear: Int
    let today: Date
    let onPick: (MonthRef) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayedYear: Int

    init(
        selection: MonthRef,
        earliestYear: Int,
        today: Date = Date(),
        onPick: @escaping (MonthRef) -> Void
    ) {
        self.selection = selection
        self.earliestYear = earliestYear
        self.today = today
        self.onPick = onPick
        _displayedYear = State(initialValue: selection.year)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var canGoBack: Bool { displayedYear > min(earliestYear, selection.year) }

    private var canGoForward: Bool { displayedYear < today.year }

    var body: some View {
        NavigationStack {
            // Fits the year row and all twelve months at any Dynamic Type size; the
            // sheet scrolls rather than letting the grid ride over the year.
            ScrollView {
                VStack(spacing: 24) {
                    yearRow
                    grid
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("Jump to month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                }
            }
        }
        .presentationDetents([.height(420), .large])
    }

    private var yearRow: some View {
        HStack {
            Button {
                displayedYear -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoBack)
            .opacity(canGoBack ? 1 : 0.35)
            .accessibilityLabel("Previous year")

            Spacer()

            Text(String(displayedYear))
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()

            Spacer()

            Button {
                displayedYear += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.35)
            .accessibilityLabel("Next year")
        }
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 8)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...12, id: \.self) { month in
                monthCell(month)
            }
        }
    }

    private func monthCell(_ month: Int) -> some View {
        let isFuture = displayedYear > today.year || (displayedYear == today.year && month > today.month)
        let isSelected = displayedYear == selection.year && month == selection.month
        let isThisMonth = displayedYear == today.year && month == today.month

        return Button {
            onPick(MonthRef(year: displayedYear, month: month))
            dismiss()
        } label: {
            Text(HomeInsights.shortMonthName(month))
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    isSelected ? AppTheme.ink : (isThisMonth ? AppTheme.cardAlternate : AppTheme.card),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(isSelected ? AppTheme.canvas : AppTheme.ink)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.35 : 1)
        .accessibilityLabel("\(HomeInsights.monthName(month)) \(displayedYear)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
