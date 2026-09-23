//
//  StreamingText.swift
//  Spendrift
//
//  Local writing: glyphs appear left to right and fade in, with a short
//  breath after punctuation so the eye has to follow the words.
//  Copy may include wait markers such as `<500ms wait>` or `<1s wait>`.
//  Markers are not shown. They hold at that point for the given duration.
//
//  Shared component: nothing here is tied to a single flow. Pass `font`,
//  `textColor`, and `cadence` to match the surface it is used on.
//

import SwiftUI

struct StreamingTextCadence: Equatable {
    /// Delay before the first glyph, so the screen can settle.
    var leadingDelayMilliseconds: Double
    /// Steady pace for letters and digits.
    var millisecondsPerCharacter: Double
    /// Pause after comma, semicolon, or colon.
    var commaPauseMilliseconds: Double
    /// Pause after period, question mark, or exclamation.
    var sentencePauseMilliseconds: Double
    /// Pause after a line break.
    var newlinePauseMilliseconds: Double
    /// How long each glyph takes to fade from clear to solid.
    /// Keep this longer than the per-character delay so a short trail
    /// of letters is still washing in as the word moves forward.
    var fadeMilliseconds: Double

    static let slow = StreamingTextCadence(
        leadingDelayMilliseconds: 480,
        millisecondsPerCharacter: 56,
        commaPauseMilliseconds: 220,
        sentencePauseMilliseconds: 420,
        newlinePauseMilliseconds: 360,
        fadeMilliseconds: 400
    )

    static let natural = StreamingTextCadence(
        leadingDelayMilliseconds: 420,
        millisecondsPerCharacter: 32,
        commaPauseMilliseconds: 140,
        sentencePauseMilliseconds: 280,
        newlinePauseMilliseconds: 220,
        fadeMilliseconds: 260
    )

    static let fast = StreamingTextCadence(
        leadingDelayMilliseconds: 260,
        millisecondsPerCharacter: 16,
        commaPauseMilliseconds: 80,
        sentencePauseMilliseconds: 160,
        newlinePauseMilliseconds: 120,
        fadeMilliseconds: 180
    )

    func delayMilliseconds(after character: Character) -> Double {
        switch character {
        case ".", "!", "?":
            sentencePauseMilliseconds
        case ",", ";", ":":
            commaPauseMilliseconds
        case "\n":
            newlinePauseMilliseconds
        case " ":
            max(10, millisecondsPerCharacter * 0.55)
        default:
            millisecondsPerCharacter
        }
    }
}

struct StreamingText: View {
    /// Visible copy, optionally with wait markers (`<500ms wait>`, `<1s wait>`).
    let text: String
    var cadence: StreamingTextCadence = .natural
    var font: Font = .system(size: 17, weight: .medium)
    var textColor: Color = .primary
    var multilineTextAlignment: TextAlignment = .leading
    var contentAlignment: Alignment = .leading
    /// Letter spacing. Set here rather than with `.tracking` outside so the reserved
    /// space and the written line are measured with the same metrics.
    var tracking: CGFloat = 0
    /// Lay the view out at the full copy's size from the first frame, so a line that is
    /// still writing itself does not push the rest of the screen around.
    var reservesSpace: Bool = false
    /// Hold at empty until this turns true. Pair it with `reservesSpace` to stage one
    /// block of copy after another without the layout moving in between.
    var startsWriting: Bool = true
    var tapSkipsToEnd: Bool = false
    /// Lower priority (e.g. `.background`) when the animation must not delay other work on the main actor.
    var writeTaskPriority: TaskPriority = .low
    /// Increment to wipe and write again.
    var replayToken: Int = 0
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed: [RevealedGlyph] = []
    @State private var isFinished = false
    @State private var fadeSettled = false
    @State private var gate = StreamGate()

    private var script: StreamingTextScript {
        StreamingTextScript.parse(text)
    }

    var body: some View {
        Group {
            if reservesSpace {
                styled(Text(script.displayText))
                    .hidden()
                    .overlay(alignment: contentAlignment) { writer }
            } else {
                writer
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(script.displayText)
        .contentShape(Rectangle())
        .onTapGesture {
            guard tapSkipsToEnd, !isFinished else { return }
            gate.skipToEnd = true
        }
        .task(id: [replayToken, startsWriting ? 1 : 0], priority: writeTaskPriority) {
            await write()
        }
    }

    private var writer: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: fadeSettled || reduceMotion)) { context in
            styled(renderedText(at: context.date))
        }
    }

    private func styled(_ text: Text) -> some View {
        text
            .font(font)
            .tracking(tracking)
            .lineSpacing(5)
            .multilineTextAlignment(multilineTextAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: contentAlignment)
    }

    private func renderedText(at now: Date) -> Text {
        var output = Text("")
        for glyph in revealed {
            let piece = Text(String(glyph.character))
                .foregroundStyle(textColor.opacity(opacity(of: glyph, at: now)))
            output = output + piece
        }
        return output
    }

    private func opacity(of glyph: RevealedGlyph, at now: Date) -> Double {
        if reduceMotion { return 1 }
        let duration = cadence.fadeMilliseconds / 1000
        guard duration > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(glyph.appearedAt)
        let t = min(1, max(0, elapsed / duration))
        return t * t * (3 - 2 * t)
    }

    @MainActor
    private func write() async {
        let script = self.script
        gate.skipToEnd = false
        revealed = []
        isFinished = false
        fadeSettled = false

        // Nothing to animate yet, so park the timeline rather than ticking at 30 Hz.
        guard startsWriting else {
            fadeSettled = true
            return
        }

        if reduceMotion || script.displayText.isEmpty {
            revealAll(script.displayText, opaque: true)
            settle()
            return
        }

        let started = await wait(cadence.leadingDelayMilliseconds)
        guard started else { return }

        if gate.skipToEnd {
            finishImmediately(script.displayText)
            return
        }

        for index in script.beats.indices {
            if Task.isCancelled { return }
            if gate.skipToEnd {
                finishImmediately(script.displayText)
                return
            }

            switch script.beats[index] {
            case .glyph(let character):
                revealed.append(
                    RevealedGlyph(
                        id: revealed.count,
                        character: character,
                        appearedAt: .now
                    )
                )

                // A breath after the last glyph has nothing to lead into; it would
                // only hold back `onFinished` and whatever is chained to it.
                if index == script.beats.count - 1 || script.hasAuthoredPause(after: index) {
                    continue
                }

                let continued = await wait(cadence.delayMilliseconds(after: character))
                guard continued else { return }

            case .pause(let milliseconds):
                let continued = await wait(milliseconds)
                guard continued else { return }
            }

            if gate.skipToEnd {
                finishImmediately(script.displayText)
                return
            }
        }

        isFinished = true
        onFinished?()

        let fadeHeld = await wait(cadence.fadeMilliseconds)
        guard fadeHeld else { return }
        fadeSettled = true
    }

    private func finishImmediately(_ displayText: String) {
        revealAll(displayText, opaque: true)
        settle()
    }

    private func revealAll(_ displayText: String, opaque: Bool) {
        let appearedAt = opaque ? Date.distantPast : .now
        revealed = displayText.enumerated().map { index, character in
            RevealedGlyph(id: index, character: character, appearedAt: appearedAt)
        }
    }

    private func settle() {
        isFinished = true
        fadeSettled = true
        onFinished?()
    }

    /// Sleep in short slices so a tap can finish the line without waiting out a sentence pause.
    private func wait(_ milliseconds: Double) async -> Bool {
        var remaining = milliseconds
        while remaining > 0 {
            if Task.isCancelled { return false }
            if gate.skipToEnd { return true }
            let slice = min(remaining, 12)
            try? await Task.sleep(nanoseconds: UInt64(slice * 1_000_000))
            remaining -= slice
        }
        return !Task.isCancelled
    }
}

private struct RevealedGlyph: Identifiable {
    let id: Int
    let character: Character
    let appearedAt: Date
}

private enum StreamBeat: Equatable {
    case glyph(Character)
    case pause(milliseconds: Double)
}

private struct StreamingTextScript {
    let displayText: String
    let beats: [StreamBeat]

    static func parse(_ source: String) -> StreamingTextScript {
        var display = ""
        var beats: [StreamBeat] = []
        var index = source.startIndex

        while index < source.endIndex {
            if let marker = consumeWaitMarker(in: source, from: index) {
                beats.append(.pause(milliseconds: marker.milliseconds))
                index = marker.endIndex
                if index < source.endIndex, source[index] == " ", display.last == " " {
                    index = source.index(after: index)
                }
                continue
            }

            let character = source[index]
            display.append(character)
            beats.append(.glyph(character))
            index = source.index(after: index)
        }

        return StreamingTextScript(displayText: display, beats: beats)
    }

    /// Authored pauses replace the usual comma / letter delay until the next visible glyph.
    func hasAuthoredPause(after index: Int) -> Bool {
        var cursor = index + 1
        while cursor < beats.count {
            switch beats[cursor] {
            case .pause:
                return true
            case .glyph(let character) where character.isWhitespace:
                cursor += 1
            case .glyph:
                return false
            }
        }
        return false
    }

    private static func consumeWaitMarker(
        in source: String,
        from start: String.Index
    ) -> (milliseconds: Double, endIndex: String.Index)? {
        guard source[start] == "<" else { return nil }

        var cursor = source.index(after: start)
        guard cursor < source.endIndex else { return nil }

        var digits = ""
        while cursor < source.endIndex {
            let character = source[cursor]
            if character.isNumber || character == "." {
                digits.append(character)
                cursor = source.index(after: cursor)
            } else {
                break
            }
        }

        guard let value = Double(digits), value >= 0 else { return nil }

        let remaining = source[cursor...]
        let milliseconds: Double
        if remaining.hasPrefix("ms") {
            milliseconds = value
            guard let next = source.index(cursor, offsetBy: 2, limitedBy: source.endIndex) else {
                return nil
            }
            cursor = next
        } else if remaining.hasPrefix("s") {
            milliseconds = value * 1000
            cursor = source.index(after: cursor)
        } else {
            return nil
        }

        while cursor < source.endIndex, source[cursor].isWhitespace {
            cursor = source.index(after: cursor)
        }

        guard source[cursor...].hasPrefix("wait") else { return nil }
        guard let afterWait = source.index(cursor, offsetBy: 4, limitedBy: source.endIndex) else {
            return nil
        }
        cursor = afterWait

        while cursor < source.endIndex, source[cursor].isWhitespace {
            cursor = source.index(after: cursor)
        }

        guard cursor < source.endIndex, source[cursor] == ">" else { return nil }
        return (milliseconds, source.index(after: cursor))
    }
}

/// Shared flag so a running write loop can see a tap without capturing stale view state.
@MainActor
private final class StreamGate {
    var skipToEnd = false
}

#Preview {
    StreamingText(
        text: """
        Welcome back. <350ms wait> Let's pick up where you left off.
        <1s wait>
        Tap the words to finish the line early.
        """,
        cadence: .natural
    )
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.listBackground)
}
