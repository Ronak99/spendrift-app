//
//  OnboardingComponents.swift
//  Spendrift
//
//  Shared visual primitives for the NeatPass-style onboarding carousel.
//

import SwiftUI

// MARK: - Theme

enum OnboardingTheme {
    static let background = Color(hex: "#0D0B14")
    static let card = Color(hex: "#1A1825")
    static let accent = Color(hex: "#02dfff")
    static let success = Color(hex: "#34C759")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
}

/// Named assets used by onboarding (mirrors app icon artwork from `AppIcon.appiconset`).
enum OnboardingVisualAsset {
    /// Same artwork as `wallet_icon.png` in the app icon set; bundled as `OnboardingHeroMark.imageset`.
    static let heroMark = "SpendriftIcon"
    /// Alternate wallet artwork used by the Pro paywall hero.
    static let proHeroMark = "SpendriftIconAlt"
}

// MARK: - Sheet background

/// Night Studio canvas with a light top-right pool of the page's CTA colour.
/// The field stays airy; the hue in the corner is the button, lifted toward white
/// so it reads as cyan / coral / green instead of a dark stain on the night fill.
struct OnboardingSheetAtmosphericBackground: View {
    var tintColor: Color

    var body: some View {
        ZStack {
            OnboardingTheme.background

            LinearGradient(
                stops: [
                    .init(color: tintColor.opacity(0.08), location: 0),
                    .init(color: tintColor.opacity(0.03), location: 0.30),
                    .init(color: OnboardingTheme.background, location: 0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.07),
                    Color.clear
                ],
                center: UnitPoint(x: 0.88, y: 0.0),
                startRadius: 0,
                endRadius: 220
            )

            RadialGradient(
                colors: [
                    tintColor.opacity(0.26),
                    tintColor.opacity(0.10),
                    Color.clear
                ],
                center: UnitPoint(x: 0.88, y: 0.0),
                startRadius: 8,
                endRadius: 300
            )
        }
        .washMotion(value: AppMotion.colorToken(tintColor))
    }
}

// MARK: - Glow + mark layers

fileprivate enum GlowingHeroIconContent {
    case sfSymbol(String)
    case asset(name: String, bundle: Bundle?, templateTint: Bool, cornerFraction: CGFloat)
}

/// Radial glow rings only (no icon). Used standalone for animated carousel heroes.
struct GlowingHeroGlow: View {
    var color: Color
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.35), color.opacity(0)],
                        center: .center,
                        startRadius: size * 0.4,
                        endRadius: size
                    )
                )
                .frame(width: size * 2.2, height: size * 2.2)
                .blur(radius: size * 0.2)

            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size * 1.35, height: size * 1.35)
        }
    }
}

// MARK: - Glossy circular glass plate (onboarding hero)

/// Circular “liquid glass” disk: frosted base, specular highlight, thin refractive rim, depth—icon sits inset with generous padding.
private struct HeroLiquidGlassCirclePlate: View {
    var diameter: CGFloat
    var accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.14),
                            accent.opacity(0.05),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.48, y: 0.42),
                        startRadius: 0,
                        endRadius: diameter * 0.58
                    )
                )

            Circle()
                .fill(
                    EllipticalGradient(
                        colors: [
                            Color.white.opacity(0.32),
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.16),
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.72
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.14)
                        ],
                        center: UnitPoint(x: 0.5, y: 0.88),
                        startRadius: 0,
                        endRadius: diameter * 0.48
                    )
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            accent.opacity(0.42),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: accent.opacity(0.26), radius: diameter * 0.14, y: diameter * 0.055)
        .shadow(color: .black.opacity(0.4), radius: diameter * 0.1, y: diameter * 0.045)
    }
}

/// Icon or asset only (no glow). Compose with `GlowingHeroGlow` or use `GlowingHeroIcon`.
/// With `liquidGlassTint`, draws a glossy circular plate and insets the icon to ~40% of the plate (breathing room).
struct GlowingHeroMark: View {
    private let content: GlowingHeroIconContent
    var color: Color
    var size: CGFloat
    /// When set, uses a circular glass disk and scales the mark for generous inner padding.
    var liquidGlassTint: Color?

    init(
        systemName: String,
        color: Color = OnboardingTheme.accent,
        size: CGFloat = 64,
        liquidGlassTint: Color? = nil
    ) {
        self.content = .sfSymbol(systemName)
        self.color = color
        self.size = size
        self.liquidGlassTint = liquidGlassTint
    }

    init(
        assetName: String,
        bundle: Bundle? = nil,
        color: Color = OnboardingTheme.accent,
        size: CGFloat = 64,
        templateTint: Bool = false,
        cornerFraction: CGFloat = 0.224,
        liquidGlassTint: Color? = nil
    ) {
        self.content = .asset(
            name: assetName,
            bundle: bundle,
            templateTint: templateTint,
            cornerFraction: cornerFraction
        )
        self.color = color
        self.size = size
        self.liquidGlassTint = liquidGlassTint
    }

    fileprivate init(content: GlowingHeroIconContent, color: Color, size: CGFloat) {
        self.content = content
        self.color = color
        self.size = size
        self.liquidGlassTint = nil
    }

    /// Plate diameter scales off the hero `size` token used by `GlowingHeroGlow`.
    private var glassPlateDiameter: CGFloat {
        size * 2.32
    }

    /// Icon ~40% of plate for premium padding (matches reference).
    private var glassInsetIconSide: CGFloat {
        glassPlateDiameter * 0.60
    }

    var body: some View {
      if let tint = liquidGlassTint {
        ZStack {
          HeroLiquidGlassCirclePlate(diameter: glassPlateDiameter, accent: tint)
          glassHeroContent
        }
      } else {
        heroMarkBody(symbolPointSize: nil, imageSide: nil)
      }
    }

    @ViewBuilder
    private var glassHeroContent: some View {
      let side = glassInsetIconSide
      let symbolSize = side * 0.92
      heroMarkBody(symbolPointSize: symbolSize, imageSide: side)
    }

    @ViewBuilder
    private func heroMarkBody(symbolPointSize: CGFloat?, imageSide: CGFloat?) -> some View {
        switch content {
        case .sfSymbol(let name):
            let pt = symbolPointSize ?? size
            Image(systemName: name)
                .font(.system(size: pt, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .shadow(
                    color: .black.opacity(liquidGlassTint != nil ? 0.38 : 0),
                    radius: liquidGlassTint != nil ? 5 : 0,
                    y: 2
                )

        case .asset(let name, let bundle, let templateTint, let cornerFraction):
            let side = imageSide ?? sizeImageSide
            assetHeroImage(
                name: name,
                bundle: bundle,
                templateTint: templateTint,
                cornerFraction: cornerFraction,
                side: side,
                useGlassShadow: liquidGlassTint != nil
            )
        }
    }

    private var sizeImageSide: CGFloat {
        size * 0.82
    }

    @ViewBuilder
    private func assetHeroImage(
        name: String,
        bundle: Bundle?,
        templateTint: Bool,
        cornerFraction: CGFloat,
        side: CGFloat,
        useGlassShadow: Bool
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: side * cornerFraction, style: .continuous)
        if templateTint {
            Image(name, bundle: bundle)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
                .foregroundStyle(color)
                .clipShape(shape)
                .shadow(
                    color: .black.opacity(useGlassShadow ? 0.34 : 0),
                    radius: useGlassShadow ? 4 : 0,
                    y: useGlassShadow ? 2 : 0
                )
        } else {
            Image(name, bundle: bundle)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
                .clipShape(shape)
                .shadow(
                    color: .black.opacity(useGlassShadow ? 0.3 : 0.22),
                    radius: useGlassShadow ? 4 : size * 0.06,
                    y: useGlassShadow ? 2 : size * 0.03
                )
        }
    }
}

/// Hero mark with radial glow behind either an SF Symbol or a catalog / bundle image.
struct GlowingHeroIcon: View {
    private let content: GlowingHeroIconContent
    var color: Color = OnboardingTheme.accent
    var size: CGFloat = 64

    init(systemName: String, color: Color = OnboardingTheme.accent, size: CGFloat = 64) {
        self.content = .sfSymbol(systemName)
        self.color = color
        self.size = size
    }

    init(
        assetName: String,
        bundle: Bundle? = nil,
        color: Color = OnboardingTheme.accent,
        size: CGFloat = 64,
        templateTint: Bool = false,
        cornerFraction: CGFloat = 0.224
    ) {
        self.content = .asset(
            name: assetName,
            bundle: bundle,
            templateTint: templateTint,
            cornerFraction: cornerFraction
        )
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            GlowingHeroGlow(color: color, size: size)
            GlowingHeroMark(content: content, color: color, size: size)
        }
    }
}

// MARK: - Shared carousel hero

enum OnboardingHeroMarkKind {
    case sfSymbol(String)
    case asset(name: String, bundle: Bundle?, templateTint: Bool, cornerFraction: CGFloat)
}

struct OnboardingHeroPageConfiguration {
    var mark: OnboardingHeroMarkKind
    var glowColor: Color
    var size: CGFloat
}

/// One fixed hero: glow tracks the active page (color + size), marks cross-fade.
struct OnboardingSharedHeroView: View {
    let currentPage: Int
    let configurations: [OnboardingHeroPageConfiguration]

    private var safePage: Int {
        guard !configurations.isEmpty else { return 0 }
        return min(max(0, currentPage), configurations.count - 1)
    }

    private var active: OnboardingHeroPageConfiguration {
        configurations[safePage]
    }

    private var maxGlowDiameter: CGFloat {
        configurations.map { $0.size * 2.55 }.max() ?? 155
    }

    var body: some View {
        ZStack {
//            GlowingHeroGlow(color: active.glowColor, size: active.size)
//                .animation(.easeInOut(duration: 0.48), value: currentPage)

            ZStack {
                ForEach(Array(configurations.enumerated()), id: \.offset) { index, config in
                    heroMark(for: config)
                        .opacity(safePage == index ? 1 : 0)
                        .allowsHitTesting(safePage == index)
                        .animation(.easeInOut(duration: 0.4), value: currentPage)
                }
            }
        }
        .frame(width: maxGlowDiameter, height: maxGlowDiameter)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func heroMark(for config: OnboardingHeroPageConfiguration) -> some View {
        let tint = config.glowColor
        switch config.mark {
        case .sfSymbol(let name):
            GlowingHeroMark(
                systemName: name,
                color: config.glowColor,
                size: config.size,
                liquidGlassTint: tint
            )
        case .asset(let name, let bundle, let templateTint, let cornerFraction):
            GlowingHeroMark(
                assetName: name,
                bundle: bundle,
                color: config.glowColor,
                size: config.size,
                templateTint: templateTint,
                cornerFraction: cornerFraction,
                liquidGlassTint: tint
            )
        }
    }
}

// MARK: - FeatureRow

struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    /// When set, the row opens this URL (e.g. Apple Shortcuts share link) in the system browser / Shortcuts.
    var shortcutURL: URL? = nil

    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let url = shortcutURL {
                Button {
                    openURL(url)
                } label: {
                    rowContent(showsLinkChevron: true)
                }
            } else {
                rowContent(showsLinkChevron: false)
            }
        }
    }

    @ViewBuilder
    private func rowContent(showsLinkChevron: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(color)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if showsLinkChevron {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color.opacity(0.85))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(shortcutURL != nil ? .isButton : [])
        .accessibilityHint(shortcutURL != nil ? "Opens a shortcut you can add in the Shortcuts app." : "")
    }
}

private struct OnboardingShortcutRowButtonStyle: ButtonStyle {
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? accent.opacity(0.12) : Color.clear)
            )
    }
}

// MARK: - PillPageIndicator

struct PillPageIndicator: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.white : Color.white.opacity(0.25))
                    .frame(width: index == current ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
            }
        }
    }
}

// MARK: - OnboardingCard

struct OnboardingCard<Content: View>: View {
    /// Per-page accent; tints the card surface and rim to match the hero / sheet atmosphere.
    var themeTint: Color
    @ViewBuilder let content: Content

    init(themeTint: Color = OnboardingTheme.accent, @ViewBuilder content: () -> Content) {
        self.themeTint = themeTint
        self.content = content()
    }

    var body: some View {
        // The content sizes the card and the surface is drawn behind it. Shapes take
        // all the room they are offered, so as siblings in a stack they would stretch
        // the card to fill any flexible slot it sits in.
        content
            .padding(20)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(OnboardingTheme.card)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeTint.opacity(0.12),
                                    themeTint.opacity(0.06),
                                    themeTint.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    themeTint.opacity(0.35),
                                    themeTint.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.65
                        )
                }
            }
    }
}

// MARK: - Glass hero

/// An asset on the glowing glass disc. The face the Pro paywall and the welcome page
/// share, so first run and the offer it leads to read as one product.
struct GlassHeroMark: View {
    let assetName: String
    var accent: Color = OnboardingTheme.accent
    var size: CGFloat = 45

    var body: some View {
        ZStack {
            GlowingHeroGlow(color: accent, size: size)
            GlowingHeroMark(
                assetName: assetName,
                color: accent,
                size: size,
                liquidGlassTint: accent
            )
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Pro feature card

/// What Spendrift's AI features do, one row each, in the paywall's card.
struct ProFeatureCard: View {
    let features: [ProFeature]
    var accent: Color = OnboardingTheme.accent
    /// Drawn in `accent`; every other row is drawn in the success green.
    var highlighted: ProFeature?

    var body: some View {
        OnboardingCard(themeTint: accent) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(features) { feature in
                    OnboardingFeatureRow(
                        icon: feature.symbolName,
                        color: feature == highlighted ? accent : OnboardingTheme.success,
                        title: feature.displayName,
                        description: feature.summary
                    )
                }
            }
        }
    }
}

#Preview {
    ZStack {
        OnboardingTheme.background.ignoresSafeArea()
        VStack(spacing: 24) {
            GlowingHeroIcon(assetName: OnboardingVisualAsset.heroMark, size: 56)
            GlowingHeroIcon(systemName: "dollarsign.circle.fill", size: 56)
            OnboardingFeatureRow(
                icon: "mic.fill",
                color: .purple,
                title: "Voice Capture",
                description: "Speak your expense and Spendrift parses it instantly."
            )
            PillPageIndicator(total: 4, current: 1)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
