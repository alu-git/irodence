import SwiftUI

/// Ultra-premium Forge Loading Screen for 铁证 / Irodence.
/// Features:
/// - Screen-blended AppLogo that seamlessly melts into the background without rectangular borders.
/// - Breathing radial ember furnace glow and ambient heat waves.
/// - Floating upward forge ember sparks (particle physics).
/// - Shimmering polished steel text animation.
struct ForgeLoadingScreen: View {
    let message: String
    var showLogo: Bool = true

    @State private var pulseScale: CGFloat = 0.95
    @State private var glowOpacity: Double = 0.4
    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        ZStack {
            Theme.Colors.surfaceBase.ignoresSafeArea()

            // Rising Forge Sparks / Floating Embers
            ForgeSparksView()
                .ignoresSafeArea()

            VStack(spacing: 32) {
                if showLogo {
                    ZStack {
                        // Ambient Radial Furnace Glow around the emblem
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Theme.Colors.ember.opacity(0.35),
                                        Theme.Colors.ember.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 130
                                )
                            )
                            .frame(width: 260, height: 260)
                            .scaleEffect(pulseScale)
                            .opacity(glowOpacity)

                        // Pure, crisp App Emblem (aura removed from logo itself)
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 155, height: 155)
                            .scaleEffect(pulseScale)
                    }
                }

                // Shimmering Forge Status Text
                ShimmeringForgeText(text: message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.06
                glowOpacity = 0.8
            }
        }
    }
}

/// Compact inline forge loading indicator for sheets, cards, and tab feeds.
struct ForgeLoadingView: View {
    let message: String?
    var size: CGFloat = 44

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 0.95

    init(_ message: String? = nil, size: CGFloat = 44) {
        self.message = message ?? L10n.t("熔铸中…", "Forging…")
        self.size = size
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background molten track
                Circle()
                    .stroke(Theme.Colors.surfaceSunken, lineWidth: 3.5)
                    .frame(width: size, height: size)

                // Glowing Ember Gradient Arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Theme.Colors.ember.opacity(0.1),
                                Theme.Colors.ember,
                                Theme.Colors.textPrimary
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotation))

                // Center glowing forge spark
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .scaleEffect(pulseScale)
            }

            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

/// Floating upward forge sparks particles
private struct ForgeSparksView: View {
    private struct Spark: Identifiable {
        let id = UUID()
        let x: CGFloat
        let size: CGFloat
        let speed: Double
        let delay: Double
        let opacity: Double
    }

    @State private var sparks: [Spark] = []
    @State private var animateSparks = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(sparks) { spark in
                    Circle()
                        .fill(Theme.Colors.ember)
                        .frame(width: spark.size, height: spark.size)
                        .position(
                            x: spark.x * proxy.size.width,
                            y: animateSparks ? -20 : proxy.size.height + 20
                        )
                        .opacity(animateSparks ? 0 : spark.opacity)
                        .shadow(color: Theme.Colors.ember, radius: 4)
                        .animation(
                            .easeOut(duration: spark.speed)
                            .repeatForever(autoreverses: false)
                            .delay(spark.delay),
                            value: animateSparks
                        )
                }
            }
            .onAppear {
                sparks = (0..<14).map { _ in
                    Spark(
                        x: CGFloat.random(in: 0.25...0.75),
                        size: CGFloat.random(in: 2...4.5),
                        speed: Double.random(in: 2.2...4.0),
                        delay: Double.random(in: 0...2.5),
                        opacity: Double.random(in: 0.5...0.9)
                    )
                }
                DispatchQueue.main.async {
                    animateSparks = true
                }
            }
        }
    }
}

/// Polished steel light-shimmer sweep across Chinese characters
private struct ShimmeringForgeText: View {
    let text: String
    @State private var phase: CGFloat = -1.0

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Theme.Colors.textSecondary,
                        Theme.Colors.textPrimary,
                        Theme.Colors.ember,
                        Theme.Colors.textPrimary,
                        Theme.Colors.textSecondary
                    ],
                    startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

/// Backwards compatibility alias
typealias GymLoadingView = ForgeLoadingView

/// iOS 16-compatible stand-in for ContentUnavailableView (iOS 17+).
struct ComingSoonView: View {
    let title: String
    let systemImage: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textMuted)
            Text(title)
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.surfaceBase.ignoresSafeArea())
    }
}

// MARK: - In-App Safari Browser Support

import SafariServices

/// In-app Safari browser modal wrapper using SFSafariViewController.
/// Keeps users inside the app when viewing external tutorials, videos, or web links.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true

        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = UIColor(Theme.Colors.ember)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Identifiable wrapper for URLs to present in `.sheet(item:)`.
struct IdentifiableURL: Identifiable, Equatable {
    let id: String
    let url: URL

    init(_ url: URL) {
        self.id = url.absoluteString
        self.url = url
    }
}

