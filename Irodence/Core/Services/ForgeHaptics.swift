import UIKit
import AudioToolbox

/// Heavy, industrial haptics engine tailored for 铁证 / Irodence.
/// Provides satisfying physical weight and punch on key workout events.
public enum ForgeHaptics {

    // Pre-warmed generators for minimum latency
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// Pre-warms feedback generators to guarantee zero-latency response during lifting.
    public static func prepare() {
        rigidImpact.prepare()
        heavyImpact.prepare()
        mediumImpact.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Core Workout Strikes

    /// Rigid metallic hammer strike when completing a standard working set.
    public static func strike() {
        rigidImpact.impactOccurred()
    }

    /// Deep heavy thud when logging a high-RPE (9-10) or heavy compound set.
    public static func heavyThud() {
        heavyImpact.impactOccurred(intensity: 1.0)
    }

    /// Multi-stage explosive celebration pulse when breaking a Personal Record (PR).
    public static func prBreak() {
        heavyImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            rigidImpact.impactOccurred(intensity: 0.9)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            notificationGenerator.notificationOccurred(.success)
        }
    }

    // MARK: - Rest Timer Feedback

    /// Soft rhythmic tick during final 3, 2, 1 seconds of rest countdown.
    public static func timerCountdownTick() {
        lightImpact.impactOccurred(intensity: 0.6)
    }

    /// Double alert buzz when the rest timer reaches 00:00.
    public static func timerFinished() {
        notificationGenerator.notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1519) // Strong actuator buzz
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            heavyImpact.impactOccurred(intensity: 0.8)
        }
    }

    // MARK: - Social & Workout Lifecycle

    /// Double medium tap when nudging a teammate (催一下).
    public static func nudge() {
        mediumImpact.impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            rigidImpact.impactOccurred(intensity: 1.0)
        }
    }

    /// Triple deep thud when quenching the furnace / completing an entire workout.
    public static func quench() {
        heavyImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            heavyImpact.impactOccurred(intensity: 0.8)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            notificationGenerator.notificationOccurred(.success)
        }
    }

    /// Subtle tick when adjusting plate steppers or scrolling wheel pickers.
    public static func selection() {
        selectionGenerator.selectionChanged()
    }

    /// Warning error shake on invalid input or network failure.
    public static func errorShake() {
        notificationGenerator.notificationOccurred(.error)
    }
}
