import SwiftUI

/// Static 1080×1350 (4:5) share card rendered offscreen via ImageRenderer —
/// sized for WeChat Moments and Douyin stories. Dark background, DOTS hero,
/// top PR, app watermark. No animations; everything explicit so the render
/// doesn't depend on the surrounding environment.
struct ShareSummaryCardView: View {
    let summary: WorkoutManager.Summary

    /// The session's most significant PR (same ranking as the summary).
    private var topPR: WorkoutManager.PRResult? {
        summary.prs.max {
            ($0.deltaKg ?? 0, $0.estimated1RM) < ($1.deltaKg ?? 0, $1.estimated1RM)
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09)
            RadialGradient(
                colors: [Color(red: 1, green: 0.55, blue: 0.35).opacity(0.28), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )

            VStack(spacing: 0) {
                HStack {
                    Text("Irodence 铁证")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(1.5)
                    Spacer()
                    Text(Date(), format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                if let dots = summary.dotsScore {
                    Text("DOTS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(3)
                    Text(String(format: "%.1f", dots))
                        .font(.system(size: 76, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 1, green: 0.55, blue: 0.35)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }

                if let pr = topPR {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text(pr.exercise.primaryName)
                            .font(.headline)
                        Spacer()
                        Text("\(formatKg(pr.estimated1RM)) kg")
                            .font(.headline.monospacedDigit())
                        if let delta = pr.deltaKg {
                            Text("+\(formatKg(delta))")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.09))
                    )
                    .padding(.top, summary.dotsScore != nil ? 18 : 0)
                }

                Spacer()

                HStack {
                    stat(value: durationText, label: "时长")
                    stat(value: volumeText, label: "总容量 kg")
                    stat(value: "\(summary.completedSets)", label: "组数")
                }
                .padding(.bottom, 14)

                Text(summary.name)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(28)
        }
        .frame(width: 360, height: 450)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
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
