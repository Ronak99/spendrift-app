//
//  VoiceLevelWaveform.swift
//  Spendrift
//
//  Voice Memos style waveform: each bar is one loudness sample mirrored around the centre
//  line, the newest sample enters at the right edge and history scrolls off to the left.
//
//  Shared by the floating capture bar and the onboarding voice demo, so the two surfaces
//  read the microphone the same way. Pass `tint` to match the surface.
//

import SwiftUI

struct VoiceLevelWaveform: View {
    let meter: VoiceInputLevelMeter
    var tint: Color = .red.opacity(0.8)
    var barWidth: CGFloat = 2.5
    var barSpacing: CGFloat = 3.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Silence draws as a dot as tall as it is wide, so the strip reads as "listening" and
    /// any speech visibly grows out of it.
    private var minBarHeight: CGFloat { barWidth }

    var body: some View {
        // Samples arrive at 20 Hz; the strip is redrawn every frame so bars glide between
        // samples instead of jumping. Reading the meter here, not inside the Canvas renderer,
        // keeps the observation tracking that re-renders when a new sample lands.
        let samples = meter.samples
        let lastSampleAt = meter.lastSampleAt

        // With Reduce Motion the strip only redraws when a sample lands; the levels stay,
        // since they are information rather than decoration, but the glide is dropped.
        let redrawInterval: Double? = reduceMotion ? VoiceInputLevelMeter.sampleInterval : nil

        TimelineView(.animation(minimumInterval: redrawInterval, paused: !meter.isRunning)) { timeline in
            Canvas { context, size in
                let midY = size.height / 2
                let pitch = barWidth + barSpacing

                let baseline = CGRect(x: 0, y: midY - 0.5, width: size.width, height: 1)
                context.fill(Path(baseline), with: .color(tint.opacity(0.25)))

                // Fraction of the sample interval already elapsed; shifts every bar left by
                // that much so the next sample can enter flush at the right edge.
                var glide: CGFloat = 0
                if !reduceMotion, let lastSampleAt {
                    let elapsed = timeline.date.timeIntervalSince(lastSampleAt)
                    glide = CGFloat(min(max(elapsed / VoiceInputLevelMeter.sampleInterval, 0), 1))
                }

                for (age, level) in samples.reversed().enumerated() {
                    let x = size.width - barWidth - (CGFloat(age) + glide) * pitch
                    guard x + barWidth > 0 else { break }
                    let height = max(minBarHeight, CGFloat(level) * size.height)
                    let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
                    context.fill(Capsule().path(in: rect), with: .color(tint))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
