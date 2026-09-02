import SwiftUI
import UIKit

/// Appearance mode setting (深色 / 浅色 / 跟随系统).
public enum AppThemeMode: String, CaseIterable, Identifiable {
    case dark = "dark"
    case light = "light"
    case system = "system"

    public var id: String { rawValue }

    public static let storageKey = "app_theme_mode"

    public var displayName: String {
        switch self {
        case .dark: return L10n.t("黑曜锻造 (深色)", "Obsidian Forge (Dark)")
        case .light: return L10n.t("极简钛白 (浅色)", "Titanium Minimal (Light)")
        case .system: return L10n.t("跟随系统", "System Default")
        }
    }

    public var iconName: String {
        switch self {
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        case .system: return "iphone"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// Design system token definitions for 铁证 / Irodence.
/// Specified in IRODENCE_DESIGN.md with dynamic Dark/Light theme adaptation.
public enum Theme {

    // MARK: - Color Tokens
    public enum Colors {
        /// App background - `#0F1012` (Dark: Obsidian Cast Iron) / `#F3F4F6` (Light: Brushed Titanium Platinum)
        public static let surfaceBase = Color.adaptive(dark: 0x0F1012, light: 0xF3F4F6)
        /// Cards, sheets - `#181A1D` (Dark: Forged Plate) / `#FFFFFF` (Light: Ceramic Titanium White)
        public static let surfaceRaised = Color.adaptive(dark: 0x181A1D, light: 0xFFFFFF)
        /// Video wells, chip pills, recessed slots - `#0B0C0E` (Dark: Deep Well) / `#EAECF0` (Light: Machined Well)
        public static let surfaceSunken = Color.adaptive(dark: 0x0B0C0E, light: 0xEAECF0)

        /// Dividers - `#1F2227` (Dark: Gunmetal Hairline) / `#E5E7EB` (Light: Precision Hairline)
        public static let borderHairline = Color.adaptive(dark: 0x1F2227, light: 0xE5E7EB)
        /// Card edges, inactive controls - `#2C3037` (Dark: Machined Steel Rim) / `#D1D5DB` (Light: Laser-cut Steel Rim)
        public static let borderMetal = Color.adaptive(dark: 0x2C3037, light: 0xD1D5DB)

        /// Headings, numerals - `#F1F3F5` (Dark: Brushed Steel) / `#111827` (Light: Deep Obsidian Ink)
        public static let textPrimary = Color.adaptive(dark: 0xF1F3F5, light: 0x111827)
        /// Body text - `#9CA3AF` (Dark: Neutral Plate) / `#4B5563` (Light: Slate Neutral)
        public static let textSecondary = Color.adaptive(dark: 0x9CA3AF, light: 0x4B5563)
        /// Labels, timestamps - `#64748B` (Dark: Slag Slate) / `#6B7280` (Light: Cool Slate)
        public static let textMuted = Color.adaptive(dark: 0x64748B, light: 0x6B7280)

        /// Primary accent. Certification stamps, 力量分 deltas, primary actions - `#EF9F27` (Dark: Molten Amber) / `#EA580C` (Light: Vibrant Forge Ember)
        public static let ember = Color.adaptive(dark: 0xEF9F27, light: 0xEA580C)
        /// High-contrast text on ember fills
        public static let emberDeep = Color.adaptive(dark: 0x1A0D00, light: 0xFFFFFF)
        /// Text on ember fills alias
        public static let textOnEmber = emberDeep
        /// Pressed state on raised surfaces - `#22262B` (Dark) / `#E5E7EB` (Light)
        public static let surfacePressed = Color.adaptive(dark: 0x22262B, light: 0xE5E7EB)
        /// Certified proof border
        public static let borderCertified = Color.adaptive(dark: 0xEF9F27, light: 0xEA580C)
        /// `#C25E4C` - Decay and lapse states only. Never for errors
        public static let rust = Color.adaptive(dark: 0xC25E4C, light: 0xDC2626)
        /// `#E24B4A` - Destructive actions, real errors
        public static let danger = Color.adaptive(dark: 0xE24B4A, light: 0xEF4444)

        // MARK: - Tier Ladder (Steel ladder from crude iron to mirror masterwork)
        /// 生铁 (Pig iron)
        public static let tierPigIron = Color.adaptive(dark: 0x3B4048, light: 0x475569)
        /// 熟铁 (Wrought iron)
        public static let tierWroughtIron = Color.adaptive(dark: 0x525964, light: 0x334155)
        /// 铸钢 (Cast steel)
        public static let tierCastSteel = Color.adaptive(dark: 0x6E7684, light: 0x1E293B)
        /// 精钢 (Refined steel)
        public static let tierRefinedSteel = Color.adaptive(dark: 0x949DAA, light: 0x0284C7)
        /// 重锻 (Reforged steel)
        public static let tierReforged = Color.adaptive(dark: 0xC0C7D2, light: 0xEA580C)
        /// 百炼 (Masterwork steel)
        public static let tierHundredFold = Color.adaptive(dark: 0xE8EEF5, light: 0xD97706)
    }

    // MARK: - Typography Tokens
    public enum Typography {
        /// Display font: Smiley Sans for stat numerals and tier names ONLY.
        /// PostScript name: SmileySans-Oblique
        public static let fontName = "SmileySans-Oblique"

        /// Size 36, Display font (Smiley Sans) for primary stat numerals
        public static var statNumeral: Font {
            .custom(fontName, size: 36, relativeTo: .largeTitle)
        }
        /// Size 24, Display font (Smiley Sans) for secondary stat numerals / cards
        public static var statNumeralSmall: Font {
            .custom(fontName, size: 24, relativeTo: .title2)
        }
        /// Size 18, Display font (Smiley Sans) for tier name badges and rungs
        public static var tierDisplay: Font {
            .custom(fontName, size: 18, relativeTo: .headline)
        }

        /// Size 28, weight 700 (.bold) - System font
        public static var largeTitle: Font {
            scaledSystemFont(size: 28, weight: .bold, textStyle: .largeTitle)
        }
        /// Size 24, weight 700 (.bold) - System font
        public static var headerTitle: Font {
            scaledSystemFont(size: 24, weight: .bold, textStyle: .title1)
        }
        /// Size 20, weight 700 (.bold) - System font
        public static var screenTitle: Font {
            scaledSystemFont(size: 20, weight: .bold, textStyle: .title2)
        }
        /// Section header title alias
        public static var sectionTitle: Font {
            screenTitle
        }
        /// Size 17, weight 600 (.semibold) - System font
        public static var cardTitle: Font {
            scaledSystemFont(size: 17, weight: .semibold, textStyle: .headline)
        }
        /// Size 15, weight 400 (.regular) - System font
        public static var body: Font {
            scaledSystemFont(size: 15, weight: .regular, textStyle: .body)
        }
        /// Size 13.5, weight 500 (.medium) - System font
        public static var label: Font {
            scaledSystemFont(size: 13.5, weight: .medium, textStyle: .subheadline)
        }
        /// Size 12, weight 500 (.medium) - System font
        public static var caption: Font {
            scaledSystemFont(size: 12, weight: .medium, textStyle: .caption1)
        }

        /// Tracking value for stat numerals
        public static let statNumeralTracking: CGFloat = 1.2

        public static func scaledSystemFont(size: CGFloat, weight: UIFont.Weight = .regular, textStyle: UIFont.TextStyle = .body) -> Font {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
            return Font(scaled)
        }
    }

    // MARK: - Shape & Corner Radius Tokens
    public enum Radius {
        /// 12 - Cards
        public static let card: CGFloat = 12
        /// 10 - Template rows
        public static let template: CGFloat = 10
        /// 8 - Controls
        public static let control: CGFloat = 8
        /// 4 - Stamps & pills
        public static let stamp: CGFloat = 4
        /// 4 - Pills
        public static let pill: CGFloat = 4
    }

    // MARK: - Border Width Tokens
    public enum Border {
        /// 1px hairline metal / divider border
        public static let hairline: CGFloat = 1
        /// 2px ember border on certified item
        public static let certified: CGFloat = 2
    }

    // MARK: - Spacing Scale Tokens
    public enum Spacing {
        /// 4
        public static let xs: CGFloat = 4
        /// 8
        public static let sm: CGFloat = 8
        /// 12
        public static let md: CGFloat = 12
        /// 14
        public static let base: CGFloat = 14
        /// 16
        public static let lg: CGFloat = 16
        /// 24
        public static let xl: CGFloat = 24
    }

    // MARK: - Tier Definitions
    public enum Tier: String, CaseIterable, Codable {
        case pigIron = "生铁"
        case wroughtIron = "熟铁"
        case castSteel = "铸钢"
        case refinedSteel = "精钢"
        case reforged = "重锻"
        case hundredFold = "百炼"

        public var displayName: String {
            rawValue
        }
    }
}

// MARK: - Color Hex & Adaptive Initializers
private extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func adaptive(dark: UInt32, light: UInt32, alpha: Double = 1.0) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: alpha)
                : UIColor(hex: light, alpha: alpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: Double = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: CGFloat(alpha))
    }
}

// MARK: - Metallic Sheen Modifier

public struct MetallicSheenModifier: ViewModifier {
    let trigger: Bool
    let angle: Angle
    let duration: Double
    let delay: Double

    @State private var sheenProgress: CGFloat = -1.2
    @State private var secondPulseProgress: CGFloat = -1.2

    public init(
        trigger: Bool = true,
        angle: Angle = Angle.degrees(25),
        duration: Double = 0.85,
        delay: Double = 0.25
    ) {
        self.trigger = trigger
        self.angle = angle
        self.duration = duration
        self.delay = delay
    }

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let size = max(geo.size.width, geo.size.height)
                    let diagonal = size * 2.2

                    ZStack {
                        // Primary Razor Sheen Band
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .white.opacity(0.0), location: 0.35),
                                .init(color: .white.opacity(0.35), location: 0.46),
                                .init(color: .white.opacity(0.95), location: 0.50),
                                .init(color: .white.opacity(0.35), location: 0.54),
                                .init(color: .white.opacity(0.0), location: 0.65),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .rotationEffect(angle)
                        .frame(width: diagonal, height: diagonal)
                        .offset(x: sheenProgress * diagonal, y: sheenProgress * (diagonal * 0.4))
                        .blendMode(.screen)

                        // Trailing Soft Glow Ribbon
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Theme.Colors.ember.opacity(0.4), location: 0.5),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .rotationEffect(angle)
                        .frame(width: diagonal * 0.6, height: diagonal * 0.6)
                        .offset(x: secondPulseProgress * diagonal, y: secondPulseProgress * (diagonal * 0.4))
                        .blendMode(.plusLighter)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            )
            .mask(content)
            .onChange(of: trigger) { newValue in
                if newValue {
                    runAnimation()
                }
            }
            .onAppear {
                if trigger {
                    runAnimation()
                }
            }
    }

    private func runAnimation() {
        sheenProgress = -1.2
        secondPulseProgress = -1.4

        withAnimation(.easeInOut(duration: duration).delay(delay)) {
            sheenProgress = 1.2
        }

        withAnimation(.easeInOut(duration: duration * 0.9).delay(delay + 0.18)) {
            secondPulseProgress = 1.2
        }
    }
}

public extension View {
    func metallicSheen(
        trigger: Bool = true,
        angle: Angle = Angle.degrees(25),
        duration: Double = 0.85,
        delay: Double = 0.25
    ) -> some View {
        self.modifier(
            MetallicSheenModifier(
                trigger: trigger,
                angle: angle,
                duration: duration,
                delay: delay
            )
        )
    }
}
