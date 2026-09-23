//
//  OnboardingFlowComponents.swift
//  Spendrift
//
//  Building blocks for the first-run walkthrough.
//
//  The flow holds one idea per page, so every page is the same three slots: narration at
//  the top, a single enamel squircle in the middle, and one capsule on the floor. Each
//  slot reserves the space its final content needs, so copy can write itself and the
//  middle can change without the headline or the button moving.
//

import SwiftUI

// MARK: - Steps

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case voice
    case pro

    var id: Int { rawValue }

    /// Page glow, wash tint, and primary capsule fill.
    var accent: Color {
        switch self {
        case .welcome: OnboardingTheme.accent
        // The tab bar's Speak control, so the plate the user is about to tap is already
        // the colour of the button they will look for afterwards.
        case .voice:   Color(hex: "#F57873")
        case .pro:     OnboardingTheme.success
        }
    }

    var analyticsName: String {
        switch self {
        case .welcome: "welcome"
        case .voice:   "voice"
        case .pro:     "pro"
        }
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Ultra-light watermark in the top-right, matching the ledger tabs.
    var watermark: OnboardingHeroPlate.Mark {
        switch self {
        case .welcome: .asset(OnboardingVisualAsset.heroMark)
        case .voice:   .symbol("mic.fill")
        case .pro:     .symbol("bell.badge.fill")
        }
    }
}

// MARK: - Page scaffold

/// The shared three-slot page. Narration is anchored to the top and the capsule to the
/// bottom; the focus slot takes whatever is left and centres its object there, so the
/// only thing that ever moves is the object itself.
///
/// The page also owns the entrance order: the line writes itself, then the object arrives,
/// then the capsule. Pass `narrationFinished` from `OnboardingNarration`.
struct OnboardingPage<Narration: View, Focus: View, Action: View>: View {
    var narrationFinished: Bool
    /// How long the capsule waits after the object arrives. Longer on a page that wants
    /// the object tried before the way out is offered.
    var actionDelay: Duration = .milliseconds(220)
    @ViewBuilder var narration: Narration
    @ViewBuilder var focus: Focus
    @ViewBuilder var action: Action

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsFocus = false
    @State private var showsAction = false

    var body: some View {
        VStack(spacing: 0) {
            // Copy at the top, capsule on the floor, and everything that moves happens
            // in the middle. Nothing in the outer two slots depends on the inner one,
            // so neither the headline nor the button shifts as a page plays out.
            narration
                .frame(maxWidth: .infinity, alignment: .topLeading)

            focus
                .frame(maxWidth: .infinity, minHeight: 128)
                .frame(maxHeight: .infinity)
                .onboardingReveal(showsFocus, reduceMotion: reduceMotion)

            action
                .frame(maxWidth: .infinity)
                .onboardingReveal(showsAction, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: narrationFinished) { _, finished in
            guard finished else { return }
            reveal()
        }
        .task {
            // Backstop. Whatever happens to the narration, a page must never be left
            // without a way forward.
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            reveal()
        }
    }

    private func reveal() {
        // Keyed to the focus, which flips at once, so the backstop firing during a long
        // action delay does not schedule the capsule a second time.
        guard !showsFocus else { return }
        let entrance: Animation? = reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)
        withAnimation(entrance) { showsFocus = true }
        Task { @MainActor in
            try? await Task.sleep(for: actionDelay)
            withAnimation(entrance) { showsAction = true }
        }
    }
}

private extension View {
    /// Rises and fades in when its turn in the page's entrance order comes up.
    func onboardingReveal(_ isVisible: Bool, reduceMotion: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.97)
            .allowsHitTesting(isVisible)
    }
}

// MARK: - Narration

/// Copy in two voices. The headline is the one white line that carries the idea; the
/// detail is smaller and quieter. Page state speaks through the hint under the hero
/// plate, not here, so the copy stays put once written.
///
/// Both streamed blocks reserve their full size up front and the detail waits for the
/// headline, so the copy writes itself without moving the object underneath it.
struct OnboardingNarration: View {
    /// White, large, one idea.
    let headline: String
    /// Everything the headline does not have to carry. Written once the headline lands.
    var detail: String?
    /// Called when the last block of copy has finished writing itself.
    var onFinished: (() -> Void)?

    @State private var headlineFinished = false

    private static let detailFont = Font.system(size: 16)

    /// The detail picks up the moment the headline's last glyph lands. The headline's
    /// own lead-in already let the screen settle, so a second one reads as a stall.
    private static let detailCadence: StreamingTextCadence = {
        var cadence = StreamingTextCadence.natural
        cadence.leadingDelayMilliseconds = 0
        return cadence
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StreamingText(
                text: headline,
                cadence: .slow,
                font: .system(size: 30, weight: .bold),
                textColor: OnboardingTheme.textPrimary,
                multilineTextAlignment: .leading,
                contentAlignment: .leading,
                tracking: -0.7,
                reservesSpace: true,
                onFinished: handleHeadlineFinished
            )

            if let detail {
                StreamingText(
                    text: detail,
                    cadence: Self.detailCadence,
                    font: Self.detailFont,
                    textColor: OnboardingTheme.textSecondary,
                    multilineTextAlignment: .leading,
                    contentAlignment: .leading,
                    reservesSpace: true,
                    startsWriting: headlineFinished,
                    onFinished: { onFinished?() }
                )
            }
        }
    }

    private func handleHeadlineFinished() {
        headlineFinished = true
        if detail == nil { onFinished?() }
    }
}

// MARK: - Hero plate

/// The one object every page is built around: the same enamel squircle the ledger uses.
/// Optionally tappable, and optionally ringed by the live microphone level.
struct OnboardingHeroPlate: View {
    enum Mark: Equatable {
        case symbol(String)
        case asset(String)
    }

    let mark: Mark
    var accent: Color
    /// Empty-state / Explore size. Large enough to be the page's only object.
    var side: CGFloat = 88
    /// Room around the tile for the level rings and the busy arc. Just enough for them,
    /// so the object does not carry a halo of empty space into the page's layout.
    private static let breathingRoom: CGFloat = 40
    /// When set, the tile is ringed by the live microphone level.
    var levelMeter: VoiceInputLevelMeter?
    var isBusy: Bool = false
    var accessibilityLabel: String?
    var action: (() -> Void)?

    /// Matches `CategoryEnamelTile`: continuous radius is 33% of the side.
    private var cornerRadius: CGFloat { side * 0.33 }

    var body: some View {
        if let action {
            Button(action: action) { plate }
                .buttonStyle(CategoryTilePressStyle())
                .accessibilityLabel(accessibilityLabel ?? "")
        } else {
            plate
                .accessibilityHidden(accessibilityLabel == nil)
                .accessibilityLabel(accessibilityLabel ?? "")
        }
    }

    private var plate: some View {
        ZStack {
            if let levelMeter {
                OnboardingLevelRings(
                    meter: levelMeter,
                    accent: accent,
                    side: side,
                    cornerRadius: cornerRadius
                )
            }

            markView
                .transition(.opacity.combined(with: .scale(scale: 0.92)))

            if isBusy {
                OnboardingBusyRing(
                    accent: accent,
                    tileSide: side,
                    tileCornerRadius: cornerRadius
                )
            }
        }
        .frame(width: side + Self.breathingRoom, height: side + Self.breathingRoom)
    }

    @ViewBuilder
    private var markView: some View {
        switch mark {
        case .symbol(let name):
            CategoryEnamelTile(systemImage: name, color: accent)
                .frame(width: side, height: side)
        case .asset(let name):
            OnboardingEnamelAsset(name: name, accent: accent, side: side)
        }
    }
}

/// Ledger-style ultra-light mark, parked past the top-right corner so only a hint remains.
struct OnboardingCornerWatermark: View {
    let mark: OnboardingHeroPlate.Mark

    /// Same size as tabs and Settings.
    private let size: CGFloat = 176
    /// Further off-canvas than the ledger (`x: 40, y: -28`) so the glyph reads as a
    /// bleed, not a second hero.
    private let hang = CGSize(width: 68, height: -45)

    var body: some View {
        glyph
            .frame(width: size, height: size)
            .foregroundStyle(OnboardingTheme.textPrimary.opacity(0.10))
            .offset(x: hang.width, y: hang.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .contentTransition(.opacity)
    }

    @ViewBuilder
    private var glyph: some View {
        switch mark {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size, weight: .ultraLight))
        case .asset(let name):
            Image(name)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .opacity(0.10)
        }
    }
}

/// Full-colour mark (the Spendrift logo) clipped to the enamel squircle so it sits in the
/// same family as `CategoryEnamelTile` without inventing a second chip shape.
private struct OnboardingEnamelAsset: View {
    let name: String
    let accent: Color
    let side: CGFloat

    var body: some View {
        let radius = side * 0.33
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: side, height: side)
            .clipShape(shape)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.55, y: 0.7)
                    )
                )
                .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
            }
            .shadow(color: accent.opacity(0.32), radius: side * 0.12, y: side * 0.08)
            .accessibilityHidden(true)
    }
}

/// Two squircles breathing with the mic. Corner radius stays on the tile so the rings
/// stay concentric as they swell.
///
/// Reads the meter itself: samples land at 20 Hz, and this keeps that invalidation off the
/// page body so the narration is not re-evaluated twenty times a second while recording.
private struct OnboardingLevelRings: View {
    let meter: VoiceInputLevelMeter
    let accent: Color
    let side: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Peak of the two newest samples, so one quiet frame mid-syllable does not collapse
    /// the rings.
    private var level: CGFloat {
        guard !reduceMotion else { return 0 }
        return CGFloat(min(max(meter.samples.suffix(2).max() ?? 0, 0), 1))
    }

    var body: some View {
        let level = self.level
        ZStack {
            ring(inset: 16, opacity: 0.35)
                .scaleEffect(1 + level * 0.09)

            ring(inset: 38, opacity: 0.16)
                .scaleEffect(1 + level * 0.16)
        }
        .animation(.easeOut(duration: 0.16), value: level)
        .accessibilityHidden(true)
    }

    private func ring(inset: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(accent.opacity(opacity), lineWidth: 1)
            .frame(width: side + inset, height: side + inset)
    }
}

/// Stroke locked to the tile while the backend is reading the clip.
///
/// The shape stays put. Only the highlight travels. Rotating a trimmed squircle tumbles
/// its corners off the button, so the outline never actually surrounds the tap target.
private struct OnboardingBusyRing: View {
    let accent: Color
    let tileSide: CGFloat
    let tileCornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gap: CGFloat = 8
    private let lineWidth: CGFloat = 2.5
    private let lap: TimeInterval = 1.15

    /// Outer edge of the stroke, one gap outside the tile.
    private var ringSide: CGFloat { tileSide + (gap + lineWidth) * 2 }
    /// Parallel outline: offsetting a rounded rect outward grows its corner radius by the same amount.
    private var ringRadius: CGFloat { tileCornerRadius + gap + lineWidth }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let turns = reduceMotion
                ? 0
                : timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: lap) / lap
            ring(turns: turns)
        }
        .accessibilityHidden(true)
    }

    private func ring(turns: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: ringRadius, style: .continuous)

        return ZStack {
            shape.strokeBorder(accent.opacity(0.22), lineWidth: lineWidth)
            shape.strokeBorder(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: accent, location: 0),
                        .init(color: accent.opacity(0.55), location: 0.12),
                        .init(color: accent.opacity(0), location: 0.34),
                        .init(color: accent.opacity(0), location: 1)
                    ]),
                    center: .center,
                    angle: .degrees(turns * 360)
                ),
                lineWidth: lineWidth
            )
        }
        .frame(width: ringSide, height: ringSide)
    }
}

// MARK: - Tap hint

/// The quiet line under a hero plate: what to do with it, or what it is doing now.
/// Always holds two rows so the plate above never moves as the hint changes or clears.
struct OnboardingTapHint: View {
    let text: String?

    var body: some View {
        Text(text ?? " ")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(OnboardingTheme.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2, reservesSpace: true)
            .frame(maxWidth: 300)
            .contentTransition(.opacity)
            .opacity(text == nil ? 0 : 1)
            .animation(.easeInOut(duration: 0.28), value: text)
            .accessibilityHidden(text == nil)
    }
}

// MARK: - Heard transaction

/// The row Spendrift heard, drawn the way the ledger draws it. This is the payoff of the
/// voice step, so it uses the real enamel tile and the real row typography rather than a
/// marketing approximation of one.
struct OnboardingHeardTransactionCard: View {
    let heard: OnboardingHeardTransaction

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CategoryEnamelTile(
                systemImage: heard.icon,
                color: heard.tint,
                showsShadow: false
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(heard.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .lineLimit(1)

                if !heard.subtitle.isEmpty {
                    Text(heard.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(heard.amountText)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(heard.isExpense ? OnboardingTheme.textPrimary : CategoryEnamel.income)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(heard.date, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(OnboardingTheme.card)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Action capsule

/// One action per page, always in the same place and always the same height, whichever
/// style it wears.
struct OnboardingActionButton: View {
    /// How loudly the action asks to be taken.
    enum Style: Equatable {
        /// The page's own next step: filled capsule in the page accent.
        case filled
        /// A way past a page whose real offer is somewhere else on screen - the plate,
        /// usually. Bare text and an arrow, so it steps aside rather than competing.
        case quiet
    }

    let title: String
    var fill: Color
    var style: Style = .filled
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    Capsule()
                        .fill(fill)
                        .opacity(style == .filled ? 1 : 0)
                }
        }
        .buttonStyle(OnboardingCapsulePressStyle())
        .animation(.easeInOut(duration: 0.32), value: style)
        .animation(.easeInOut(duration: 0.32), value: title)
    }

    private var label: some View {
        HStack(spacing: 10) {
            Text(title)
                .contentTransition(.opacity)

            if style == .quiet {
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
        }
        .font(.headline)
        .foregroundStyle(style == .filled ? OnboardingTheme.background : OnboardingTheme.textSecondary)
    }

    private struct OnboardingCapsulePressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
        }
    }
}

#if DEBUG
#Preview("Busy plate") {
    ZStack {
        OnboardingSheetAtmosphericBackground(tintColor: OnboardingStep.voice.accent)
            .ignoresSafeArea()
        OnboardingHeroPlate(
            mark: .symbol("mic.fill"),
            accent: OnboardingStep.voice.accent,
            isBusy: true,
            accessibilityLabel: "Reading it back"
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Page scaffold") {
    ZStack {
        OnboardingSheetAtmosphericBackground(tintColor: OnboardingStep.voice.accent)
            .ignoresSafeArea()

        OnboardingPage(narrationFinished: true) {
            OnboardingNarration(
                headline: "Just say it.",
                detail: "One tap, one sentence. Done."
            )
        } focus: {
            VStack(spacing: 8) {
                OnboardingHeroPlate(
                    mark: .symbol("mic.fill"),
                    accent: OnboardingStep.voice.accent,
                    accessibilityLabel: "Start speaking",
                    action: {}
                )
                OnboardingTapHint(text: "Tap me")
            }
        } action: {
            OnboardingActionButton(
                title: "Awesome, next",
                fill: OnboardingStep.voice.accent,
                action: {}
            )
        }
    }
    .preferredColorScheme(.dark)
}
#endif
