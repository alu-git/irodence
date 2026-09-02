import SwiftUI

/// Detailed Preview Sheet for a BuiltIn or Custom Workout Template.
/// Lifters can inspect all exercises, target muscle breakdown, set/rep schemes,
/// toggle favorite status for the home screen, and start the workout with 1 tap.
struct TemplatePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var manager: WorkoutManager
    @EnvironmentObject private var library: ExerciseService
    @ObservedObject private var favoritesManager = FavoriteTemplatesManager.shared

    let template: BuiltInTemplate
    let onStartWorkout: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // 1. Clean Hero Header Card (No text wall)
                        heroHeaderCard

                        // 2. Blueprint Exercise List
                        exercisesSection

                        // Bottom padding for sticky action bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                }

                // Sticky Bottom Action Bar
                VStack {
                    Spacer()
                    bottomActionBar
                }
            }
            .navigationTitle(L10n.t("图纸详情", "Template Blueprint"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        favoritesManager.toggleFavorite(id: template.id)
                        ForgeHaptics.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: favoritesManager.isFavorite(id: template.id) ? "star.fill" : "star")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(favoritesManager.isFavorite(id: template.id) ? Theme.Colors.ember : Theme.Colors.textMuted)
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 1. Clean Hero Header Card

    private var heroHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Badges Row
            HStack(spacing: 8) {
                // Category Pill
                Text(template.category.displayName)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                            .strokeBorder(Theme.Colors.ember.opacity(0.4), lineWidth: Theme.Border.hairline)
                    )

                // Duration Pill
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11.5))
                    Text(L10n.t("约 \(template.estimatedMinutes) 分钟", "~\(template.estimatedMinutes) min"))
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))

                // Difficulty Pill
                Text(template.difficulty)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))

                Spacer()
            }

            // Title
            Text(template.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            // Target Muscles Tag Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(template.targetMuscles, id: \.self) { muscle in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Theme.Colors.ember)
                                .frame(width: 5.5, height: 5.5)
                            Text(muscle.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.surfaceSunken, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 2. Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("动作编排 (\(template.items.count) 项)", "Exercise Lineup (\(template.items.count) Lifts)"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 2)

            VStack(spacing: 11) {
                ForEach(Array(template.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 14) {
                        // Index or Superset Indicator
                        if let group = item.supersetGroup {
                            VStack(spacing: 2) {
                                Text("SS")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.emberDeep)
                                Text(supersetLetter(group))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.Colors.emberDeep)
                            }
                            .frame(width: 38, height: 42)
                            .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: 6))
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .frame(width: 38, height: 42)
                                .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                                 )
                        }

                        // Exercise details
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.system(size: 16.5, weight: .bold))
                                .foregroundStyle(Theme.Colors.textPrimary)

                            HStack(spacing: 6) {
                                Text(item.targetMuscle.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.Colors.ember)

                                Text("·")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.Colors.textMuted)

                                Text(L10n.t("推荐 \(item.defaultSets) 组 × \(item.targetReps) 次", "Suggested \(item.defaultSets) sets × \(item.targetReps) reps"))
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }

                        Spacer()

                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .fill(Theme.Colors.surfaceRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )
                }
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            // Favorite Button
            Button {
                favoritesManager.toggleFavorite(id: template.id)
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: favoritesManager.isFavorite(id: template.id) ? "star.fill" : "star")
                        .font(.system(size: 20, weight: .semibold))
                    Text(favoritesManager.isFavorite(id: template.id) ? L10n.t("已设常练", "Favorited") : L10n.t("设为常练", "Favorite"))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(favoritesManager.isFavorite(id: template.id) ? Theme.Colors.ember : Theme.Colors.textSecondary)
                .frame(width: 68, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(favoritesManager.isFavorite(id: template.id) ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
            }
            .buttonStyle(.plain)

            // Start Workout Button
            Button {
                dismiss()
                onStartWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(L10n.t("开启本次训练", "Start This Workout"))
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.ember)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Theme.Colors.surfaceBase
                .shadow(color: Color.black.opacity(0.7), radius: 16, y: -4)
        )
    }

    private func supersetLetter(_ group: Int) -> String {
        let letters = ["A", "B", "C", "D", "E"]
        return letters[safe: group - 1] ?? "\(group)"
    }
}
