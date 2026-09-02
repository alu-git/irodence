import SwiftUI
import UIKit
import Pow
import Vortex

/// Motion and particle effect tokens for 铁证 / Irodence.
/// Wraps Pow and Vortex behind domain-specific named modifiers so views never invoke third-party animation libraries directly.
/// Adheres strictly to IRODENCE_DESIGN.md and motion rules:
/// - All effects honor UIAccessibility.isReduceMotionEnabled.
/// - Colors restricted to Theme.Colors (ember, emberDeep).
/// - Exactly 5 approved motion moments in the application.
public enum Effects {

    // MARK: - 1. Hammer Strike (Set Completion)
    /// Subtle impact shake + light haptic feedback on completing a workout set.
    public struct HammerStrikeModifier<V: Equatable>: ViewModifier {
        let trigger: V
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public func body(content: Content) -> some View {
            if reduceMotion || UIAccessibility.isReduceMotionEnabled {
                content
            } else {
                content
                    .changeEffect(.shake(rate: .fast), value: trigger)
            }
        }
    }

    // MARK: - 2. Shine Sweep (Certified Stamp Appearing)
    /// Single-pass 600-900ms shine sweep across a certified stamp once it is fully legible.
    public struct ShineSweepModifier<V: Equatable>: ViewModifier {
        let trigger: V
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public func body(content: Content) -> some View {
            if reduceMotion || UIAccessibility.isReduceMotionEnabled {
                content
            } else {
                content
                    .changeEffect(
                        .shine(angle: .degrees(25), duration: 0.8),
                        value: trigger
                    )
            }
        }
    }

    // MARK: - 3. Rust Clears Transition
    /// Transition for member row rust badge clearing when a rusted user logs a session.
    public static var rustClears: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        } else {
            return .movingParts.poof
        }
    }

    // MARK: - 6. Consent Warning Shake (Login Screen)
    /// Subtle shake effect when attempting to log in without agreeing to terms.
    public struct ConsentShakeModifier<V: Equatable>: ViewModifier {
        let trigger: V
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public func body(content: Content) -> some View {
            if reduceMotion || UIAccessibility.isReduceMotionEnabled {
                content
            } else {
                content
                    .changeEffect(.shake(rate: .fast), value: trigger)
            }
        }
    }
}

// MARK: - View Extension Wrappers

public extension View {
    /// Applies a hammer strike impact effect when `trigger` changes, paired with light haptic.
    func hammerStrike<V: Equatable>(trigger: V) -> some View {
        modifier(Effects.HammerStrikeModifier(trigger: trigger))
    }

    /// Applies a 800ms single-pass shine sweep across the view when `trigger` changes.
    func shineSweep<V: Equatable>(trigger: V) -> some View {
        modifier(Effects.ShineSweepModifier(trigger: trigger))
    }

    /// Applies a shake warning effect on the view when `trigger` changes.
    func consentShake<V: Equatable>(trigger: V) -> some View {
        modifier(Effects.ConsentShakeModifier(trigger: trigger))
    }
}

// MARK: - Industrial Physical Button Styles

public struct ForgePressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public struct ForgeCardPressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.982 : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

public struct PlatePillPressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .animation(.spring(response: 0.16, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == ForgePressStyle {
    static var forgePress: ForgePressStyle { ForgePressStyle() }
}

public extension ButtonStyle where Self == ForgeCardPressStyle {
    static var forgeCardPress: ForgeCardPressStyle { ForgeCardPressStyle() }
}

public extension ButtonStyle where Self == PlatePillPressStyle {
    static var platePillPress: PlatePillPressStyle { PlatePillPressStyle() }
}

// MARK: - 4. Tier-Up Spark Burst (Vortex)

/// One-shot 1.2s ember spark burst for tier advancements in the summary screen. No looping.
public struct TierUpSparksView: View {
    let isTriggered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isTriggered: Bool) {
        self.isTriggered = isTriggered
    }

    public var body: some View {
        if reduceMotion || UIAccessibility.isReduceMotionEnabled || !isTriggered {
            EmptyView()
        } else {
            VortexView(createTierUpSystem()) {
                Circle()
                    .fill(Theme.Colors.ember)
                    .frame(width: 6, height: 6)
                    .tag("circle")

                Circle()
                    .fill(Theme.Colors.emberDeep)
                    .frame(width: 4, height: 4)
                    .tag("spark")
            }
            .allowsHitTesting(false)
        }
    }

    private func createTierUpSystem() -> VortexSystem {
        let system = VortexSystem(tags: ["circle", "spark"])
        system.position = [0.5, 0.5]
        system.shape = .box(width: 0.8, height: 0.1)
        system.birthRate = 0
        system.emissionLimit = 35
        system.lifespan = 1.2
        system.speed = 0.4
        system.speedVariation = 0.2
        system.angle = .degrees(270)
        system.angleRange = .degrees(120)
        system.size = 0.6
        system.sizeVariation = 0.3
        system.isEmitting = true
        return system
    }
}

// MARK: - 5. Furnace Heat Meter Ambient Emitter (Vortex)

/// Rising ember particles behind the 炉温 numeral in CrewView.
/// Particle count and velocity scale dynamically with heat percentage (0.0 - 1.0).
/// Pauses when view is offscreen and no-ops under reduce-motion.
public struct FurnaceHeatMeterView: View {
    let heatPercentage: Double
    let isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(heatPercentage: Double, isPaused: Bool = false) {
        self.heatPercentage = min(max(heatPercentage, 0.0), 1.0)
        self.isPaused = isPaused
    }

    public var body: some View {
        if reduceMotion || UIAccessibility.isReduceMotionEnabled || isPaused || heatPercentage <= 0.02 {
            Color.clear
        } else {
            VortexView(createFurnaceSystem()) {
                Circle()
                    .fill(Theme.Colors.ember.opacity(0.75))
                    .blur(radius: 1)
                    .frame(width: 5, height: 5)
                    .tag("ember")

                Circle()
                    .fill(Theme.Colors.emberDeep.opacity(0.6))
                    .frame(width: 3, height: 3)
                    .tag("spark")
            }
            .allowsHitTesting(false)
        }
    }

    private func createFurnaceSystem() -> VortexSystem {
        let system = VortexSystem(tags: ["ember", "spark"])
        system.position = [0.5, 1.0]
        system.shape = .box(width: 0.9, height: 0.05)
        // Particle count and speed scaled to heat percentage
        system.birthRate = 4.0 + heatPercentage * 10.0
        system.lifespan = 1.6
        system.speed = 0.12 + heatPercentage * 0.2
        system.speedVariation = 0.1
        system.angle = .degrees(270)
        system.angleRange = .degrees(35)
        system.size = 0.5
        system.sizeVariation = 0.3
        system.isEmitting = !isPaused
        return system
    }
}
