import SwiftUI

/// Post-workout reward moment: DOTS hero with count-up, staggered PR cards,
/// tier progress, streak, and a shareable summary card. The whole entrance
/// sequence lands in ~1.5s so it stays satisfying on repeat viewing.
struct WorkoutSummaryView: View {
    let summary: WorkoutManager.Summary
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var displayedDots: Double = 0
    @State private var tierProgress: Double = 0
    @State private var sharePulse = false
    @State private var shareImage: Image?

    // MARK: - Stagger timing (top to bottom, ~90ms steps)

    private let heroDelay = 0.05
    private let statsDelay = 0.16
    private let prBaseDelay = 0.27
    private let prStep = 0.09

    private var tierDelay: Double {
        prBaseDelay + Double(max(summary.prs.count, 1)) * prStep + 0.05
    }
    private var shareDelay: Double {
        (summary.tierMoment != nil ? tierDelay + 0.12 : tierDelay) + 0.05
    }

    /// PRs ordered by significance: biggest 1RM jump first, first-time
    /// records after improvements (tie-broken by absolute est. 1RM).
    private var orderedPRs: [WorkoutManager.PRResult] {
        summary.prs.sorted {
            ($0.deltaKg ?? 0, $0.estimated1RM) > ($1.deltaKg ?? 0, $1.estimated1RM)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView {
                    VStack(spacing: 14) {
                        if summary.dotsScore != nil { heroSection }
                        statsCard
                        if !orderedPRs.isEmpty { prSection }
                        if let moment = summary.tierMoment { tierCard(moment) }
                        shareButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(summary.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { runEntrance() }
            .task { renderShareCard() }
        }
    }

    // MARK: - Background

    /// Dark system background with a faint accent glow — no photography.
    private var background: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            RadialGradient(
                colors: [Color.accentColor.opacity(0.22), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - DOTS hero

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("本次 DOTS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(2)

            CountUpText(value: displayedDots)
                .frame(maxWidth: .infinity)

            if let delta = summary.dotsDelta, abs(delta) >= 0.05 {
                Text(String(format: "%+.1f DOTS · 较近期平均", delta))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(delta >= 0 ? .green : .red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill((delta >= 0 ? Color.green : Color.red).opacity(0.15))
                    )
            }

            if summary.streakWeeks >= 2 {
                Label("训练连续 \(summary.streakWeeks) 周", systemImage: "flame.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .staggered(appeared: appeared, delay: heroDelay)
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack {
            stat(value: durationText, label: "时长", systemImage: "clock")
            Divider().frame(height: 36)
            stat(value: volumeText, label: "总容量 (kg)", systemImage: "scalemass")
            Divider().frame(height: 36)
            stat(value: "\(summary.completedSets)", label: "完成组数", systemImage: "checkmark.circle")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cardFill)
        .staggered(appeared: appeared, delay: statsDelay)
    }

    private func stat(value: String, label: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - PRs

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("新纪录")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(orderedPRs.enumerated()), id: \.element.id) { index, pr in
                let delay = prBaseDelay + Double(index) * prStep
                if index == 0 {
                    heroPRCard(pr, delay: delay)
                } else {
                    prRow(pr, delay: delay)
                }
            }
        }
    }

    /// The session's biggest breakthrough: larger card, accent highlight.
    private func heroPRCard(_ pr: WorkoutManager.PRResult, delay: Double) -> some View {
        HStack(spacing: 14) {
            TrophyBadge(hero: true, delay: delay)
                .font(.title)
            VStack(alignment: .leading, spacing: 3) {
                Text(pr.exercise.primaryName)
                    .font(.title3.weight(.bold))
                Text("\(formatKg(pr.weightKg)) kg × \(pr.reps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("估算 1RM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(formatKg(pr.estimated1RM)) kg")
                    .font(.title2.weight(.bold).monospacedDigit())
                prDeltaText(pr)
            }
        }
        .padding(16)
        .background(cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.accentColor, .yellow.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .staggered(appeared: appeared, delay: delay)
    }

    private func prRow(_ pr: WorkoutManager.PRResult, delay: Double) -> some View {
        HStack(spacing: 12) {
            TrophyBadge(hero: false, delay: delay)
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exercise.primaryName).font(.headline)
                Text("\(formatKg(pr.weightKg)) kg × \(pr.reps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(formatKg(pr.estimated1RM)) kg")
                    .font(.headline.monospacedDigit())
                prDeltaText(pr)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardFill)
        .staggered(appeared: appeared, delay: delay)
    }

    @ViewBuilder
    private func prDeltaText(_ pr: WorkoutManager.PRResult) -> some View {
        if let delta = pr.deltaKg {
            Text("(+\(formatKg(delta)) kg)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.green)
        } else {
            Text("首次纪录")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
        }
    }

    // MARK: - Tier progress

    private func tierCard(_ moment: WorkoutManager.TierMoment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(moment.lift.displayName, systemImage: moment.tier.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(moment.tier.color)
                Spacer()
                if let next = moment.nextTier, let gap = moment.dotsToNext {
                    Text("距\(next.displayName)还差 \(String(format: "%.0f", gap)) DOTS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("已达最高等级")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(moment.tier.color)
                        .frame(width: max(geo.size.width * tierProgress, 8))
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(cardFill)
        .staggered(appeared: appeared, delay: tierDelay)
    }

    // MARK: - Share

    @ViewBuilder
    private var shareButton: some View {
        let label = HStack {
            Image(systemName: "square.and.arrow.up")
            Text("分享成绩")
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.white)
        .shadow(color: Color.accentColor.opacity(sharePulse ? 0.55 : 0.2),
                radius: sharePulse ? 14 : 4)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                   value: sharePulse)

        if let shareImage {
            ShareLink(item: shareImage, preview: SharePreview("训练总结", image: shareImage)) {
                label
            }
            .staggered(appeared: appeared, delay: shareDelay)
        } else {
            label
                .opacity(0.6)
                .staggered(appeared: appeared, delay: shareDelay)
        }
    }

    @MainActor
    private func renderShareCard() {
        let renderer = ImageRenderer(content: ShareSummaryCardView(summary: summary))
        renderer.proposedSize = .init(width: 360, height: 450)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    // MARK: - Entrance sequence + haptics

    private func runEntrance() {
        appeared = true
        tierProgress = summary.tierMoment?.progressBefore ?? 0

        // DOTS count-up, then a success haptic when it lands.
        if let dots = summary.dotsScore {
            withAnimation(.easeOut(duration: 0.75).delay(heroDelay + 0.15)) {
                displayedDots = dots
            }
            let notifier = UINotificationFeedbackGenerator()
            notifier.prepare()
            schedule(after: heroDelay + 0.15 + 0.75) {
                notifier.notificationOccurred(.success)
            }
        }

        // Light haptic as each PR card lands.
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        for index in summary.prs.indices {
            schedule(after: prBaseDelay + Double(index) * prStep) {
                impact.impactOccurred()
            }
        }

        // Tier bar fills from the old value to the new one.
        if let moment = summary.tierMoment {
            withAnimation(.easeInOut(duration: 0.8).delay(tierDelay + 0.15)) {
                tierProgress = moment.progressAfter
            }
        }

        // Share button starts pulsing once the sequence has played out.
        schedule(after: shareDelay + 0.5) { sharePulse = true }
    }

    private func schedule(after seconds: Double, action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            action()
        }
    }

    // MARK: - Formatting

    private var cardFill: some View {
        RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.07))
    }

    private var durationText: String {
        let total = Int(summary.duration)
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h)时\(m)分" : "\(m)分钟"
    }

    private var volumeText: String {
        let v = summary.totalVolumeKg
        return v >= 1000 ? String(format: "%.1fk", v / 1000) : "\(Int(v))"
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

// MARK: - Staggered entrance modifier

private extension View {
    /// Fade + slide-up entrance gated on `appeared`, offset y: 20 → 0.
    func staggered(appeared: Bool, delay: Double) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.easeOut(duration: 0.45).delay(delay), value: appeared)
    }
}

// MARK: - Count-up label

/// Interpolates its number during an animated value change (DOTS hero).
private struct CountUpText: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(String(format: "%.1f", value))
            .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Color.accentColor],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }
}

// MARK: - Trophy badge

/// One-shot bounce (1 → peak → 1, spring) plus a brief glow flash on
/// appearance. `delay` keeps it in sync with the card's staggered entrance.
private struct TrophyBadge: View {
    let hero: Bool
    let delay: Double
    @State private var scale: CGFloat = 1
    @State private var glow = false

    var body: some View {
        Image(systemName: "trophy.fill")
            .foregroundStyle(.yellow)
            .scaleEffect(scale)
            .shadow(color: .yellow.opacity(glow ? 0.9 : 0), radius: glow ? 10 : 0)
            .onAppear {
                let peak: CGFloat = hero ? 1.15 : 1.08
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45).delay(delay)) {
                    scale = peak
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(delay + 0.28)) {
                    scale = 1
                }
                withAnimation(.easeIn(duration: 0.15).delay(delay)) { glow = true }
                withAnimation(.easeOut(duration: 0.6).delay(delay + 0.35)) { glow = false }
            }
    }
}
