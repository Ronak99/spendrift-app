//
//  CyclingSearchPlaceholder.swift
//  Spendrift
//
//  "Search" followed by a word that cycles through what search covers. The word
//  slides up into place while "Search" stays put; Reduce Motion fades it instead.
//

import SwiftUI

struct CyclingSearchPlaceholder: View {
    static let subjects = ["transactions", "categories", "accounts", "merchants", "notes"]

    /// Stable spoken form, so VoiceOver never reads whichever word is showing.
    static let accessibilityText = "Search transactions, categories, accounts, merchants and notes"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("Search")
            wordSlot
                .overlay(alignment: .leading) {
                    ZStack(alignment: .leading) {
                        Text(Self.subjects[index])
                            .id(index)
                            .transition(wordTransition)
                    }
                    // Scoped here so the swap animates only the word, never the row.
                    .animation(.easeInOut(duration: 0.35), value: index)
                }
                // Clips so the sliding word appears from under the baseline.
                .clipped()
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText)
        // Cancelled when the view leaves the screen, so the cycle never runs unseen.
        .task {
            while true {
                do {
                    try await Task.sleep(for: .seconds(2.4))
                } catch {
                    return
                }
                index = (index + 1) % Self.subjects.count
            }
        }
    }

    /// Every word stacked invisibly, so the slot keeps the longest word's size and
    /// a fixed baseline. The visible word rides in an overlay on top, which keeps
    /// it out of layout: swapping it can never nudge "Search".
    private var wordSlot: some View {
        ZStack(alignment: .leading) {
            ForEach(Self.subjects, id: \.self) { subject in
                Text(subject)
            }
        }
        .hidden()
    }

    private var wordTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}
