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

enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case voice
    case backup
    case notifications

    var id: Int { rawValue }

    /// Page glow, wash tint, and primary capsule fill.
    var accent: Color {
        switch self {
        case .welcome: OnboardingTheme.accent
        // The tab bar's Speak control, so the plate the user is about to tap is already
        // the colour of the button they will look for afterwards.
        case .voice:   Color(hex: "#F57873")
        // Sky blue, between the welcome cyan and the notifications violet, so the
        // sequence of washes steps through the spectrum rather than doubling back.
        case .backup:  Color(hex: "#5B9DFF")
        case .notifications: Color(hex: "#9B7BFF")
        }
    }

    var analyticsName: String {
        switch self {
        case .welcome: "welcome"
        case .voice:   "voice"
        case .backup:  "backup"
        case .notifications: "notifications"
        }
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Position in the counted run of pages, from 1. The welcome page is the cover and
    /// is not counted, so the count starts where the walkthrough does: with the voice
    /// demo.
    var pageNumber: Int? {
        guard self != .welcome else { return nil }
        return rawValue - OnboardingStep.voice.rawValue + 1
    }

    /// How many pages are counted. The "3" in "1/3".
    static let countedPageCount = allCases.count - 1
}

// MARK: - Page scaffold

/// The shared three-slot page. Narration is anchored to the top and the capsule to the
/// bottom; the focus slot takes whatever is left and centres its object there, so the
/// only thing that ever moves is the object itself.
///
/// Moving between pages is a navigation push, so the page is fully on screen as it
/// arrives. Nothing here fades itself in on top of that.
struct OnboardingPage<Narration: View, Focus: View, Action: View>: View {
    @ViewBuilder var narration: Narration
    @ViewBuilder var focus: Focus
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 0) {
            // Copy at the top, capsule on the floor, and everything that moves happens
            // in the middle. Nothing in the outer two slots depends on the inner one,
            // so neither the headline nor the button shifts as a page plays out.
            narration
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .layoutPriority(1)

            focus
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            action
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
        }
        .padding(.horizontal, 28)
        // The navigation bar already clears the status area, so this is only the gap
        // under the bar.
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Narration

/// Copy in two voices. The headline is the one white line that carries the idea; the
/// detail is smaller and quieter. Page state speaks through the hint under the hero
/// plate, not here, so the copy never changes once the page is up.
///
/// All of it is on screen from the first frame. Nobody should wait to read a page.
struct OnboardingNarration: View {
    /// White, large, one idea.
    let headline: String
    /// Everything the headline does not have to carry.
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.7)
                .foregroundStyle(OnboardingTheme.textPrimary)

            if let detail {
                Text(detail)
                    .font(.system(size: 16))
                    .foregroundStyle(OnboardingTheme.textSecondary)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
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

/// "1/3" in the top-right of the bar: how far along the walkthrough they are, and how
/// much is left. Sits where the back chevron sits on the other side, in the same quiet
/// ink as the detail copy, so it informs without competing with the headline.
struct OnboardingPageCounter: View {
    let page: Int
    let total: Int

    var body: some View {
        Text("\(page)/\(total)")
            .font(.system(size: 15, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(OnboardingTheme.textSecondary)
            .accessibilityLabel("Page \(page) of \(total)")
    }
}

/// Full-colour mark (the Spendrift logo) clipped to the enamel squircle so it sits in the
/// same family as `CategoryEnamelTile` without inventing a second chip shape.
private struct OnboardingEnamelAsset: View {
    let name: String
    let accent: Color
    let side: CGFloat
    var showsShadow: Bool = true
    var showGradient: Bool = true

    var body: some View {
        let radius = side * 0.33
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: side, height: side)
            .clipShape(shape)
            .overlay {
                if showGradient {
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .clear],
                            startPoint: .topLeading,
                            endPoint: UnitPoint(x: 0.55, y: 0.7)
                        )
                    )
                    .allowsHitTesting(false)
                }  
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
            }
            .shadow(
                color: showsShadow ? accent.opacity(0.32) : .clear,
                radius: showsShadow ? side * 0.12 : 0,
                y: showsShadow ? side * 0.08 : 0
            )
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

// MARK: - Notification tile

/// One example notification. The page owns the list, so adding another is another value.
struct OnboardingNotification: Identifiable, Hashable {
    let title: String
    let message: String
    /// Relative stamp, such as "3m ago".
    var time: String
    /// The line under the deck while this one is up front: why it is worth a ping.
    var hint: String? = nil

    var id: String { title }
}

/// A banner drawn the same way as `OnboardingHeardTransactionCard`: card fill, hairline,
/// padding, 44pt enamel squircle, and the ledger row's type scale.
///
/// Fills the height it is offered, so banners of different lengths can share one size.
struct OnboardingNotificationTile: View {
    let notification: OnboardingNotification
    /// Banners waiting behind the front one are blank cards, so only one reads at a time.
    var showsContent = true

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            OnboardingEnamelAsset(
                name: OnboardingVisualAsset.heroMark,
                accent: OnboardingStep.notifications.accent,
                side: 44,
                showsShadow: false,
                showGradient: false
            )

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
    
                    Text(notification.message)
                        .font(.system(size: 12))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(notification.time)
                    .monospacedDigit()
                    .font(.system(size: 11))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .opacity(showsContent ? 1 : 0)
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(OnboardingTheme.card)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example notification. \(notification.title). \(notification.message)")
    }
}

/// The notifications page's deck: one banner up front and two more hinted behind it.
/// Every few seconds the front one is swiped away and the rest move up, and the user can
/// swipe it away themselves. A banner that leaves rejoins at the back.
///
/// Needs more banners than it shows, so the one that just left has somewhere to wait
/// off screen before it fades back in behind the others.
struct OnboardingNotificationDeck: View {
    let notifications: [OnboardingNotification]
    /// The banner up front. The page reads it to put that banner's line under the deck.
    @Binding var front: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Horizontal travel of the front banner while it is being dragged.
    @State private var drag: CGFloat = 0
    /// Which way the last banner left, so one flicked right does not exit to the left.
    @State private var exitDirection: CGFloat = -1
    /// Bumped by a swipe, so the next automatic one waits a full interval again.
    @State private var swipes = 0
    @State private var width: CGFloat = 0

    private static let interval: Duration = .seconds(3)
    /// Banners on screen at once: the front one and the two peeking under it.
    private static let visible = 3
    /// How far each banner behind the front one drops.
    private static let peek: CGFloat = 14
    /// How much each banner behind the front one shrinks.
    private static let shrink: CGFloat = 0.07
    private static let depthOpacity: [Double] = [1, 0.8, 0.5]

    var body: some View {
        // Every banner, laid out once and hidden, so the deck is as tall as its longest
        // banner and all of them share that height.
        ZStack {
            ForEach(notifications) { notification in
                OnboardingNotificationTile(notification: notification)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .hidden()
        .accessibilityHidden(true)
        .overlay(alignment: .top) {
            ZStack(alignment: .top) {
                ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                    card(notification, depth: depth(of: index))
                }
            }
        }
        // Room for the banners peeking under the front one.
        .padding(.bottom, Self.peek * CGFloat(Self.visible - 1))
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .sensoryFeedback(.impact(weight: .light), trigger: swipes)
        .task(id: swipes) {
            guard !reduceMotion, notifications.count > Self.visible else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                // Never pull a banner out from under a finger.
                guard !Task.isCancelled, drag == 0 else { continue }
                advance(toward: -1)
            }
        }
    }

    /// 0 is the front. Anything at `visible` or beyond has left and is waiting off screen.
    private func depth(of index: Int) -> Int {
        (index - front + notifications.count) % notifications.count
    }

    private func card(_ notification: OnboardingNotification, depth: Int) -> some View {
        let isGone = depth >= Self.visible
        let slot = CGFloat(min(depth, Self.visible - 1))

        return OnboardingNotificationTile(notification: notification, showsContent: depth == 0)
            .shadow(color: .black.opacity(depth == 0 || isGone ? 0.45 : 0), radius: 20, y: 20)
            .scaleEffect(isGone ? 1 : 1 - Self.shrink * slot, anchor: .top)
            .offset(
                x: isGone ? exitDirection * width * 1.25 : (depth == 0 ? drag : 0),
                y: isGone ? 0 : Self.peek * slot
            )
            .animation(moveAnimation(depth), value: depth)
            .opacity(isGone ? 0 : Self.depthOpacity[depth])
            .animation(fadeAnimation(depth), value: depth)
            // A leaving banner slides over the ones moving up into its place.
            .zIndex(isGone ? Double(notifications.count) : Double(notifications.count - depth - 1))
            .allowsHitTesting(depth == 0)
            .accessibilityHidden(depth != 0)
            .accessibilityAction(named: "Next example") {
                swipes += 1
                advance(toward: -1)
            }
    }

    /// The front banner flicks out fast. The rest wait a beat for it to clear, then
    /// settle into their new places. One arriving at the back jumps there unseen.
    private func moveAnimation(_ depth: Int) -> Animation? {
        if depth >= Self.visible {
            return .timingCurve(0.55, 0, 0.9, 0.4, duration: 0.28)
        }
        if depth == Self.visible - 1 { return nil }
        return .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45).delay(0.12)
    }

    /// Opacity follows the move, except at the ends: a leaving banner vanishes only once
    /// it is off screen, and one arriving at the back fades in after the others settle.
    private func fadeAnimation(_ depth: Int) -> Animation? {
        if depth >= Self.visible { return .linear(duration: 0.04).delay(0.26) }
        if depth == Self.visible - 1 { return .easeInOut(duration: 0.5).delay(0.3) }
        return moveAnimation(depth)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { drag = $0.translation.width }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                guard abs(projected) > width * 0.35 else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drag = 0 }
                    return
                }
                swipes += 1
                advance(toward: projected < 0 ? -1 : 1)
            }
    }

    /// Sends the front banner out to one side. The card animations key off depth, so
    /// changing `front` is all it takes, and the leaving banner starts from wherever
    /// the finger left it.
    private func advance(toward direction: CGFloat) {
        exitDirection = direction
        front = (front + 1) % notifications.count
        drag = 0
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

#Preview("Notification tile") {
    ZStack {
        OnboardingSheetAtmosphericBackground(tintColor: OnboardingStep.notifications.accent)
            .ignoresSafeArea()
        OnboardingNotificationTile(
            notification: OnboardingNotification(
                title: "Premium Refilled",
                message: "Your 10 voice notes are ready for the month. Let's track!",
                time: "3m ago"
            )
        )
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28)
    }
    .preferredColorScheme(.dark)
}

#Preview("Page scaffold") {
    ZStack {
        OnboardingSheetAtmosphericBackground(tintColor: OnboardingStep.voice.accent)
            .ignoresSafeArea()

        OnboardingPage {
            OnboardingNarration(
                headline: "Just say it.",
                detail: "Track expenses by speaking them out loud."
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
                title: "Next",
                fill: OnboardingStep.voice.accent,
                action: {}
            )
        }
    }
    .preferredColorScheme(.dark)
}
#endif
