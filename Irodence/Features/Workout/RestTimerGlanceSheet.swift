import SwiftUI

/// Full-screen Gym Floor Glance HUD for the rest timer.
/// Provides massive, high-contrast numerals legible from across the gym floor with one-tap quick adjustments.
struct RestTimerGlanceSheet: View {
    @Binding var restEndsAt: Date?
    @Binding var duration: TimeInterval
    let nextTarget: String?
    @Environment(\.dismiss) private var dismiss
    @State private var lastSecond: Int = -1

    private let presets: [TimeInterval] = [60, 90, 120, 180, 240, 300]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                if let endsAt = restEndsAt {
                    let remaining = max(0, endsAt.timeIntervalSince(context.date))
                    let progress = min(max(1.0 - (remaining / max(duration, 1)), 0), 1)

                    glanceContent(remaining: remaining, progress: progress)
                        .onChange(of: Int(remaining)) { sec in
                            handleCountdownHaptics(remaining: sec)
                        }
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(Theme.Colors.ember)
                        Text(L10n.t("休息结束", "Rest Finished"))
                            .font(Theme.Typography.headerTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Button(L10n.t("回到训练", "Return to Workout")) {
                            dismiss()
                        }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.emberDeep)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    }
                }
            }
        }
        .onAppear {
            ForgeHaptics.prepare()
        }
    }

    private func glanceContent(remaining: TimeInterval, progress: Double) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Top Nav Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("组间沉浸休息", "Rest Interval"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                    if let nextTarget, !nextTarget.isEmpty {
                        Text(L10n.t("下一组: \(nextTarget)", "Next: \(nextTarget)"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.ember)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)

            Spacer()

            // Giant Central Dial & Monospaced Countdown
            ZStack {
                // Background Track Ring
                Circle()
                    .stroke(Theme.Colors.surfaceSunken, lineWidth: 14)
                    .frame(width: 240, height: 240)

                // Animated Glowing Ember Progress Ring
                Circle()
                    .trim(from: 0, to: CGFloat(1.0 - progress))
                    .stroke(
                        remaining <= 5 ? Theme.Colors.rust : Theme.Colors.ember,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 240, height: 240)
                    .shadow(color: (remaining <= 5 ? Theme.Colors.rust : Theme.Colors.ember).opacity(0.4), radius: 12)
                    .animation(.linear(duration: 0.2), value: progress)

                // Digits
                VStack(spacing: 4) {
                    Text(timeString(remaining))
                        .font(.system(size: 64, weight: .heavy, design: .monospaced))
                        .foregroundStyle(remaining <= 5 ? Theme.Colors.rust : Theme.Colors.textPrimary)

                    Text(L10n.t("目标: \(timeString(duration))", "Target: \(timeString(duration))"))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            Spacer()

            // Quick Preset Selection Chips
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        duration = preset
                        restEndsAt = Date().addingTimeInterval(preset)
                        ForgeHaptics.selection()
                    } label: {
                        Text(timeString(preset))
                            .font(.system(size: 13, weight: duration == preset ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(duration == preset ? Theme.Colors.emberDeep : Theme.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .fill(duration == preset ? Theme.Colors.ember : Theme.Colors.surfaceRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .strokeBorder(duration == preset ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                    }
                    .buttonStyle(.platePillPress)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)

            // Giant Increment Adjustment Controls
            HStack(spacing: 12) {
                // -15s
                Button {
                    adjustTime(-15)
                } label: {
                    Text("-15s")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.forgePress)

                // +30s
                Button {
                    adjustTime(30)
                } label: {
                    Text("+30s")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.forgePress)

                // +60s
                Button {
                    adjustTime(60)
                } label: {
                    Text("+60s")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Colors.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.forgePress)
            }
            .padding(.horizontal, Theme.Spacing.md)

            // Skip / Start Next Set Button (Primary)
            Button {
                ForgeHaptics.strike()
                restEndsAt = nil
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(L10n.t("跳过休息 · 开始下组", "Skip Rest & Start Next Set"))
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.ember)
                )
            }
            .buttonStyle(.forgePress)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }

    private func adjustTime(_ delta: TimeInterval) {
        ForgeHaptics.selection()
        if let endsAt = restEndsAt {
            let newEndsAt = endsAt.addingTimeInterval(delta)
            if newEndsAt.timeIntervalSinceNow > 0 {
                restEndsAt = newEndsAt
            } else {
                restEndsAt = nil
                dismiss()
            }
        }
    }

    private func handleCountdownHaptics(remaining: Int) {
        guard remaining != lastSecond else { return }
        lastSecond = remaining

        if remaining >= 1 && remaining <= 3 {
            ForgeHaptics.timerCountdownTick()
        } else if remaining == 0 {
            ForgeHaptics.timerFinished()
            restEndsAt = nil
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
