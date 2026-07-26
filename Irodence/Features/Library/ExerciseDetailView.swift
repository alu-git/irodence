import SwiftUI
import Charts

/// Exercise detail: bilingual name, muscle group, equipment, instructions,
/// plus est-1RM history chart and PR info once the user has logged sets.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @StateObject private var progress = ProgressService()
    /// Start empty so the highlights fade in on appear.
    @State private var primaryHighlighted: Set<Muscle> = []
    @State private var secondaryHighlighted: Set<Muscle> = []

    private var activation: ExerciseMuscles {
        ExerciseMuscleMap.muscles(for: exercise)
    }

    var body: some View {
        List {
            Section {
                MuscleDiagramPairView(
                    activated: primaryHighlighted,
                    secondaryActivated: secondaryHighlighted
                )
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 16) {
                    Label("主要", systemImage: "circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Label("协同", systemImage: "circle.fill")
                        .foregroundStyle(Color.accentColor.opacity(0.45))
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }
            .listRowBackground(Color.clear)

            Section {
                LabeledContent(L10n.t("主要肌群", "Primary Muscle"), value: exercise.primaryMuscle.displayName)
                LabeledContent(L10n.t("器械", "Equipment"), value: exercise.equipment.displayName)
                LabeledContent(L10n.t("类型", "Type"), value: exercise.isCompound ? L10n.t("复合动作", "Compound") : L10n.t("孤立动作", "Isolation"))
            }

            if let instructions = exercise.instructions, !instructions.isEmpty {
                Section(L10n.t("动作要领", "Instructions")) {
                    Text(instructions)
                        .font(.body)
                }
            }

            Section(L10n.t("进步曲线 (估算 1RM)", "Strength Progress (Est. 1RM)")) {
                if progress.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if progress.history.count >= 2 {
                    StrengthHistoryChart(points: progress.history)
                        .frame(height: 180)
                        .padding(.vertical, 4)
                    if let first = progress.history.first, let last = progress.history.last {
                        let delta = last.estimated1RM - first.estimated1RM
                        Label(
                            delta >= 0
                                ? "较首次记录 +\(String(format: "%.1f", delta)) kg"
                                : "较首次记录 \(String(format: "%.1f", delta)) kg",
                            systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right"
                        )
                        .font(.caption)
                        .foregroundStyle(delta >= 0 ? .green : .red)
                    }
                } else {
                    Text("至少两次训练记录后显示曲线")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(exercise.primaryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(exercise.primaryName).font(.headline)
                    Text(exercise.secondaryName).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await progress.loadHistory(exerciseID: exercise.id)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5).delay(0.15)) {
                primaryHighlighted = activation.primary
                secondaryHighlighted = activation.secondary
            }
        }
    }
}

/// Est-1RM over time. Shared by exercise detail and (potentially) profile.
struct StrengthHistoryChart: View {
    let points: [StrengthHistoryPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("日期", point.date, unit: .day),
                y: .value("1RM", point.estimated1RM)
            )
            .interpolationMethod(.catmullRom)
            PointMark(
                x: .value("日期", point.date, unit: .day),
                y: .value("1RM", point.estimated1RM)
            )
            .symbolSize(20)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    /// Pad the range so a flat line still renders sensibly.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.estimated1RM)
        let lo = (values.min() ?? 0) * 0.95
        let hi = max((values.max() ?? 1) * 1.05, lo + 1)
        return lo...hi
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: Exercise(
            id: UUID(),
            nameEn: "Bench Press",
            nameZh: "杠铃卧推",
            primaryMuscle: .chest,
            equipment: .barbell,
            isCompound: true,
            instructionsZh: "仰卧于卧推凳，握距略宽于肩。",
            instructionsEn: "Lie on a bench, grip slightly wider than shoulders."
        ))
        .preferredColorScheme(.dark)
    }
}
