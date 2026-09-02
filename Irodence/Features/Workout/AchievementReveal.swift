import SwiftUI

/// Modal reveal presenting an unlocked achievement with sparks and Ember action.
struct AchievementReveal: View {
    let achievement: AchievementItem
    let onDismiss: () -> Void

    @State private var sparksTriggered = false
    @State private var badgeAppeared = false

    var body: some View {
        ZStack {
            Theme.Colors.surfaceBase
                .ignoresSafeArea()

            // Subtle background spark particles
            TierUpSparksView(isTriggered: sparksTriggered)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // 1. Hero Badge Visual (Large & Prominent)
                ZStack {
                    if let tier = achievement.tier {
                        // Ambient Radial Aura Glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        tier.color.opacity(0.4),
                                        tier.color.opacity(0.12),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 150
                                )
                            )
                            .frame(width: 300, height: 300)
                            .scaleEffect(badgeAppeared ? 1.0 : 0.7)
                            .opacity(badgeAppeared ? 1.0 : 0)

                        Image(tier.assetImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 210, height: 210)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(tier.color.opacity(0.7), lineWidth: 3)
                            )
                            .shadow(color: tier.color.opacity(0.55), radius: 32, y: 8)
                            .scaleEffect(badgeAppeared ? 1.0 : 0.5)
                            .opacity(badgeAppeared ? 1.0 : 0)
                    } else {
                        Circle()
                            .fill(Theme.Colors.surfaceRaised)
                            .frame(width: 180, height: 180)
                            .overlay(
                                Circle()
                                    .strokeBorder(achievement.badgeColor, lineWidth: 3.5)
                            )
                            .shadow(color: achievement.badgeColor.opacity(0.4), radius: 28)

                        Image(systemName: achievement.systemImage)
                            .font(.system(size: 80, weight: .bold))
                            .foregroundStyle(achievement.badgeColor)
                            .scaleEffect(badgeAppeared ? 1.0 : 0.5)
                            .opacity(badgeAppeared ? 1.0 : 0)
                    }
                }
                .metallicSheen(trigger: badgeAppeared, duration: 1.0, delay: 0.35)

                // 2. Category Pill & Title
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: achievement.category == .tierUp ? "flame.fill" : "trophy.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(achievement.category == .tierUp ? L10n.t("段位淬火晋升", "TIER PROMOTION") : L10n.t("成就达成", "ACHIEVEMENT UNLOCKED"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Theme.Colors.ember)
                    .tracking(1.5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.surfaceRaised, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Theme.Colors.ember.opacity(0.5), lineWidth: 1)
                    )

                    Text(achievement.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }

                // 3. High-Contrast Legible Description
                Text(achievement.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // 4. Exactly one Ember-filled button: "收下"
                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                        Text(L10n.t("收下", "Claim"))
                            .font(Theme.Typography.cardTitle)
                    }
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.ember)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                sparksTriggered = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                    badgeAppeared = true
                }
            }
        }
    }
}
