import SwiftUI

/// Expanded view of one feed workout: every exercise with its full set list
/// (weight × reps), per-exercise volume, and a muscle diagram thumbnail.
struct WorkoutDetailView: View {
    let item: FeedItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsRow
                ForEach(item.exercises) { exercise in
                    exerciseSection(exercise)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Who + when — taps through to their profile.
    private var header: some View {
        NavigationLink(value: FeedDestination.profile(userID: item.userID,
                                                      displayName: item.displayName)) {
            HStack(spacing: 10) {
                AvatarView(name: item.displayName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.relativeTimeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat(item.durationText, L10n.t("时长", "Time"), "clock")
            stat(item.volumeText, L10n.t("容量", "Volume"), "scalemass")
            stat("\(item.setCount)", L10n.t("组数", "Sets"), "checkmark.circle")
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Label(value, systemImage: icon)
                .font(.subheadline.monospacedDigit().weight(.medium))
                .labelStyle(.titleAndIcon)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseSection(_ exercise: FeedExerciseSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MiniMuscleDiagram(primary: exercise.muscles.primary,
                                  secondary: exercise.muscles.secondary)
                    .frame(width: 30, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text("\(exercise.setCount) \(L10n.t("组", "sets")) · \(volumeText(exercise.volumeKg))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Set list: index, weight × reps; warmups dimmed and labeled.
            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                HStack(spacing: 12) {
                    Text(set.isWarmup ? L10n.t("热身", "W") : "\(workingSetIndex(upTo: index, in: exercise))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)
                    Text("\(set.weightText) kg × \(set.reps)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(set.isWarmup ? .secondary : .primary)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// 1-based index among non-warmup sets only.
    private func workingSetIndex(upTo index: Int, in exercise: FeedExerciseSummary) -> Int {
        exercise.sets.prefix(through: index).filter { !$0.isWarmup }.count
    }

    private func volumeText(_ kg: Double) -> String {
        kg >= 1000
            ? String(format: "%.1fk kg", kg / 1000)
            : "\(Int(kg)) kg"
    }
}
