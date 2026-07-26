import SwiftUI

/// Post-workout summary: duration, volume, sets, and any PRs hit.
struct WorkoutSummaryView: View {
    let summary: WorkoutManager.Summary
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var trophyPulse = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        stat(value: durationText, label: "时长", systemImage: "clock")
                        Divider()
                        stat(value: volumeText, label: "总容量 (kg)", systemImage: "scalemass")
                        Divider()
                        stat(value: "\(summary.completedSets)", label: "完成组数", systemImage: "checkmark.circle")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.4), value: appeared)
                }
                .listRowBackground(Color.clear)

                if !summary.prs.isEmpty {
                    Section("新纪录") {
                        ForEach(Array(summary.prs.enumerated()), id: \.element.id) { index, pr in
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                    .scaleEffect(trophyPulse ? 1.25 : 1.0)
                                    .animation(
                                        .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                                        value: trophyPulse
                                    )
                                VStack(alignment: .leading) {
                                    Text(pr.exercise.primaryName).font(.headline)
                                    Text("\(formatKg(pr.weightKg)) kg × \(pr.reps)")
                                        .font(.subheadline)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("估算 1RM")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(formatKg(pr.estimated1RM)) kg")
                                        .font(.headline.monospacedDigit())
                                }
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(
                                .easeOut(duration: 0.4).delay(0.15 + Double(index) * 0.08),
                                value: appeared
                            )
                        }
                    }
                }
            }
            .navigationTitle(summary.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                appeared = true
                trophyPulse = true
            }
        }
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
