//
//  HoldToSpeakButton.swift
//  Spendrift
//
//  Created by Ronak Punase on 05/09/26.
//

import SwiftUI
import UIKit

/// Drives the "hold the `+` to talk" affordance: a quick tap behaves like a normal
/// button, while holding for `requiredHold` seconds starts voice capture directly.
/// While the control is held, `progress` builds from 0 to 1 so the caller can render a
/// left-to-right buildup along the bottom of the navigation bar; releasing early cancels
/// with no action.
@Observable
@MainActor
final class HoldToSpeakController {
    /// 0...1 buildup while the control is held; drives `NavBarHoldProgressBar`.
    private(set) var progress: Double = 0

    /// True from press-down until release. Guards against repeated gesture callbacks
    /// restarting the timer, and stops a completed hold from firing a second capture
    /// before the finger actually lifts.
    private(set) var isHolding = false

    /// Seconds the user must hold before voice capture fires.
    let requiredHold: TimeInterval = 3.0

    private var task: Task<Void, Never>?
    /// Set once the hold reaches `requiredHold`, so the matching release is not treated as a tap.
    private var didComplete = false

    /// Begin a press. `enabled` gates only the hold (for example `false` while a capture is
    /// already running) so the progress bar neither appears nor fires a redundant capture —
    /// a tap still opens the manual sheet in that case.
    func beginPress(enabled: Bool, onComplete: @escaping () -> Void) {
        guard !isHolding else { return }
        isHolding = true
        didComplete = false
        progress = 0
        guard enabled else { return }

        let startedAt = Date()
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(startedAt)
                self.progress = min(elapsed / self.requiredHold, 1)
                if self.progress >= 1 {
                    self.didComplete = true
                    self.task = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.easeOut(duration: 0.25)) { self.progress = 0 }
                    onComplete()
                    return
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    /// End the current press. Returns `true` when it ended without completing a hold —
    /// i.e. it was a tap and the caller should run its tap action.
    @discardableResult
    func endPress() -> Bool {
        guard isHolding else { return false }
        isHolding = false
        task?.cancel()
        task = nil
        let wasTap = !didComplete
        if wasTap {
            withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
        }
        didComplete = false
        return wasTap
    }
}

/// A button that opens on tap and starts voice capture when held for three seconds.
/// It is intentionally gesture-driven rather than a `Button` so tap and hold resolve to
/// exactly one action per press (a `Button` action would still fire on the release that
/// ends a completed hold).
struct HoldToSpeakButton<Label: View>: View {
    let controller: HoldToSpeakController
    /// Whether the hold-to-speak gesture is currently allowed. A tap still works when false.
    let holdEnabled: Bool
    let onTap: () -> Void
    let onHoldComplete: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var isPressed = false

    var body: some View {
        label()
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.4 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { isPressed = true }
                        controller.beginPress(enabled: holdEnabled, onComplete: onHoldComplete)
                    }
                    .onEnded { _ in
                        isPressed = false
                        if controller.endPress() {
                            onTap()
                        }
                    }
            )
            .accessibilityAddTraits(.isButton)
    }
}

/// A thin progress line rendered along the bottom edge of the navigation bar while the
/// `+` is being held, filling left-to-right as the three-second hold builds up.
struct NavBarHoldProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Color.accentColor)
                .frame(width: max(0, geo.size.width * progress), height: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 3)
        .opacity(progress > 0 ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
