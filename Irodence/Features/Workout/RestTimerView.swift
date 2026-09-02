import SwiftUI

/// Prominent floating rest-timer HUD banner shown after completing a set.
/// Designed for quick glancing across the gym floor with large numerals and one-tap controls.
struct RestTimerView: View {
    @Binding var restEndsAt: Date?
    @Binding var duration: TimeInterval
    var nextTarget: String? = nil

    @State private var showGlanceSheet = false
    @State private var lastSecond: Int = -1

    private let presets: [TimeInterval] = [60, 90, 120, 180, 240, 300]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            if let endsAt = restEndsAt {
                let remaining = max(0, endsAt.timeIntervalSince(context.date))
                let progress = min(max(1.0 - (remaining / max(duration, 1)), 0), 1)

                if remaining <= 0 {
                    Color.clear.onAppear {
                        ForgeHaptics.timerFinished()
                        RestTimerNotificationManager.cancelRestNotification()
                        restEndsAt = nil
                    }
                } else {
                    banner(remaining: remaining, progress: progress)
                        .onChange(of: Int(remaining)) { sec in
                            handleCountdownHaptics(remaining: sec)
                        }
                }
            }
        }
        .sheet(isPresented: $showGlanceSheet) {
            RestTimerGlanceSheet(
                restEndsAt: $restEndsAt,
                duration: $duration,
                nextTarget: nextTarget
            )
        }
        .onAppear {
            ForgeHaptics.prepare()
            RestTimerNotificationManager.requestAuthorization()
            if let endsAt = restEndsAt {
                RestTimerNotificationManager.scheduleRestNotification(endsAt: endsAt, nextExerciseName: nextTarget)
            }
        }
        .onChange(of: restEndsAt) { newEndsAt in
            if let newEndsAt {
                RestTimerNotificationManager.scheduleRestNotification(endsAt: newEndsAt, nextExerciseName: nextTarget)
            } else {
                RestTimerNotificationManager.cancelRestNotification()
            }
        }
    }

    private func banner(remaining: TimeInterval, progress: Double) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Circular Progress Arc Ring
            Button {
                showGlanceSheet = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.surfaceSunken, lineWidth: 3.5)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: CGFloat(1.0 - progress))
                        .stroke(
                            remaining <= 5 ? Theme.Colors.rust : Theme.Colors.ember,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)

                    Image(systemName: "timer")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(remaining <= 5 ? Theme.Colors.rust : Theme.Colors.ember)
                }
            }
            .buttonStyle(.plain)

            // Tap-to-Glance Monospaced Digits & Subtitle
            Button {
                showGlanceSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(L10n.t("组间休息", "Rest Interval"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textMuted)

                        if let nextTarget, !nextTarget.isEmpty {
                            Text("· \(nextTarget)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Colors.ember)
                                .lineLimit(1)
                        }
                    }

                    Text(timeString(remaining))
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundStyle(remaining <= 5 ? Theme.Colors.rust : Theme.Colors.textPrimary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Quick Adjust -15s
            Button {
                adjustTime(-15)
            } label: {
                Text("-15s")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.surfaceSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )
            }
            .buttonStyle(.platePillPress)

            // Quick Adjust +30s
            Button {
                adjustTime(30)
            } label: {
                Text("+30s")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(Theme.Colors.surfaceSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )
            }
            .buttonStyle(.platePillPress)

            // Skip Button
            Button {
                ForgeHaptics.strike()
                RestTimerNotificationManager.cancelRestNotification()
                restEndsAt = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(8)
            }
            .buttonStyle(.forgePress)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(remaining <= 5 ? Theme.Colors.rust : Theme.Colors.borderMetal, lineWidth: remaining <= 5 ? Theme.Border.certified : Theme.Border.hairline)
        )
        .overlay(alignment: .bottom) {
            // Bottom glowing progress line
            GeometryReader { geo in
                Rectangle()
                    .fill(remaining <= 5 ? Theme.Colors.rust : Theme.Colors.ember)
                    .frame(width: geo.size.width * CGFloat(1.0 - progress), height: 2.5)
            }
            .frame(height: 2.5)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .shadow(color: Color.black.opacity(0.6), radius: 12, y: 4)
    }

    private func adjustTime(_ delta: TimeInterval) {
        ForgeHaptics.selection()
        if let endsAt = restEndsAt {
            let newEndsAt = endsAt.addingTimeInterval(delta)
            if newEndsAt.timeIntervalSinceNow > 0 {
                restEndsAt = newEndsAt
            } else {
                restEndsAt = nil
            }
        }
    }

    private func handleCountdownHaptics(remaining: Int) {
        guard remaining != lastSecond else { return }
        lastSecond = remaining

        if remaining >= 1 && remaining <= 3 {
            ForgeHaptics.timerCountdownTick()
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

