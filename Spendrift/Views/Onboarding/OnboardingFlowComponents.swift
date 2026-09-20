//
//  OnboardingFlowComponents.swift
//  Spendrift
//
//  Building blocks for the first-run walkthrough.
//
//  The flow holds one idea per page, so every page is the same three slots: a line of
//  narration up top, a single enamel squircle in the middle, and one capsule at the bottom.
//  Keeping the geometry identical across pages is what lets the pages slide past each
//  other without anything appearing to jump.
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

/// The shared three-slot page. `narration` is pinned to a floor height so the enamel tile
/// in `focus` lands on the same baseline whether the copy runs to one line or three.
///
/// The page also owns the entrance order: the line writes itself, then the object arrives,
/// then the capsule. Pass `narrationFinished` from `OnboardingNarration`.
struct OnboardingPage<Narration: View, Focus: View, Action: View>: View {
    var narrationFinished: Bool
    @ViewBuilder var narration: Narration
    @ViewBuilder var focus: Focus
    @ViewBuilder var action: Action

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsFocus = false
    @State private var showsAction = false

    var body: some View {
        VStack(spacing: 0) {
            narration
                .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)

            Spacer(minLength: 28)

            focus
                .frame(maxWidth: .infinity, minHeight: 208)
                .onboardingReveal(showsFocus, reduceMotion: reduceMotion)

            Spacer(minLength: 28)

            action
                .frame(maxWidth: .infinity)
                .onboardingReveal(showsAction, reduceMotion: reduceMotion)
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 32)
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
        guard !showsAction else { return }
        let entrance: Animation? = reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)
        withAnimation(entrance) { showsFocus = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
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

/// Streamed headline with an optional quiet line underneath that can change while the
/// headline stays put - the subline carries state, the headline carries the idea.
struct OnboardingNarration: View {
    let headline: String
    var subline: String?
    var onHeadlineFinished: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StreamingText(
                text: headline,
                cadence: .natural,
                font: .system(size: 27, weight: .semibold),
                textColor: OnboardingTheme.textPrimary,
                multilineTextAlignment: .leading,
                contentAlignment: .leading,
                onFinished: onHeadlineFinished
            )
            .tracking(-0.5)

            // Two lines are reserved whether or not there is a line to show, so the
            // subline can change - or arrive late - without nudging the object below it.
            Text(subline ?? " ")
                .font(.system(size: 15))
                .foregroundStyle(subline == nil ? .clear : OnboardingTheme.textSecondary)
                .lineLimit(2, reservesSpace: true)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.28), value: subline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(subline == nil)
        }
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
                    side: side + 20,
                    cornerRadius: cornerRadius
                )
            }
        }
        .frame(width: side + 56, height: side + 56)
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

/// Arc that orbits the tile while the backend is reading the clip. Its own view so the
/// `repeatForever` rotation starts on insertion and dies with it.
private struct OnboardingBusyRing: View {
    let accent: Color
    let side: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpinning = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .trim(from: 0, to: 0.18)
            .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .opacity(reduceMotion ? 0.6 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
            .accessibilityHidden(true)
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

/// One capsule per page, always in the same place. `isPrimary` swaps the fill for a
/// hairline outline so a page can offer a way out without changing the layout.
struct OnboardingActionButton: View {
    let title: String
    var fill: Color
    var isPrimary: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .contentTransition(.opacity)
                .foregroundStyle(isPrimary ? OnboardingTheme.background : OnboardingTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    ZStack {
                        Capsule()
                            .fill(fill)
                            .opacity(isPrimary ? 1 : 0)
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                            .opacity(isPrimary ? 0 : 1)
                    }
                }
        }
        .buttonStyle(OnboardingCapsulePressStyle())
        .animation(.easeInOut(duration: 0.32), value: isPrimary)
        .animation(.easeInOut(duration: 0.32), value: title)
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
#Preview("Page scaffold") {
    ZStack {
        OnboardingSheetAtmosphericBackground(tintColor: OnboardingStep.voice.accent)
            .ignoresSafeArea()

        OnboardingPage(narrationFinished: true) {
            OnboardingNarration(
                headline: "Everyone makes you log an expense by hand.",
                subline: "Tap the mic and say what you spent."
            )
        } focus: {
            OnboardingHeroPlate(
                mark: .symbol("mic.fill"),
                accent: OnboardingStep.voice.accent,
                accessibilityLabel: "Start speaking",
                action: {}
            )
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
