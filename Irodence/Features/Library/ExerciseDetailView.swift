import SwiftUI
import Charts

enum ChartMetric: String, CaseIterable {
    case oneRM, maxWeight
    var displayName: String {
        switch self {
        case .oneRM: return L10n.t("估算 1RM", "Est. 1RM")
        case .maxWeight: return L10n.t("最大重量", "Max Weight")
        }
    }
}

/// Exercise detail: bilingual name, muscle group, equipment, instructions,
/// metric chart toggle (Est 1RM vs Max Weight), plus detailed guide modal link.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @StateObject private var progress = ProgressService()
    
    @State private var primaryHighlighted: Set<Muscle> = []
    @State private var secondaryHighlighted: Set<Muscle> = []
    @State private var selectedMetric: ChartMetric = .oneRM
    @State private var showDetailedGuide = false

    private var activation: ExerciseMuscles {
        ExerciseMuscleMap.muscles(for: exercise)
    }

    private var best1RM: Double? {
        progress.history.map(\.estimated1RM).max()
    }

    var body: some View {
        List {
            Section {
                MuscleDiagramPairView(
                    activated: primaryHighlighted,
                    secondaryActivated: secondaryHighlighted
                )
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                HStack(spacing: Theme.Spacing.md) {
                    Label(L10n.t("主要", "Primary"), systemImage: "circle.fill")
                        .foregroundStyle(Theme.Colors.ember)
                    Label(L10n.t("协同", "Secondary"), systemImage: "circle.fill")
                        .foregroundStyle(Theme.Colors.ember.opacity(0.45))
                }
                .font(Theme.Typography.caption)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }
            .listRowBackground(Color.clear)

            Section {
                LabeledContent(L10n.t("主要肌群", "Primary Muscle"), value: exercise.primaryMuscle.displayName)
                LabeledContent(L10n.t("器械", "Equipment"), value: exercise.equipment.displayName)
                LabeledContent(L10n.t("类型", "Type"), value: exercise.isCompound ? L10n.t("复合动作", "Compound") : L10n.t("孤立动作", "Isolation"))
            }
            .listRowBackground(Theme.Colors.surfaceRaised)

            Section(header: Text(L10n.t("动作要领", "Instructions")).font(Theme.Typography.label).foregroundStyle(Theme.Colors.textMuted)) {
                if let instructions = exercise.instructions, !instructions.isEmpty {
                    Text(instructions)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.vertical, 2)
                }
                
                Button {
                    showDetailedGuide = true
                } label: {
                    HStack {
                        Label(
                            L10n.t("查看完整动作指南与图解教程 ➔", "View Detailed Guide & Video Tutorial ➔"),
                            systemImage: "book.fill"
                        )
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.ember)
                    }
                }
            }
            .listRowBackground(Theme.Colors.surfaceRaised)

            Section(header: Text(L10n.t("进步曲线", "Strength Progress")).font(Theme.Typography.label).foregroundStyle(Theme.Colors.textMuted)) {
                Picker(L10n.t("指标", "Metric"), selection: $selectedMetric) {
                    ForEach(ChartMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)

                if progress.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                } else if progress.history.count >= 2 {
                    StrengthHistoryChart(points: progress.history, metric: selectedMetric)
                        .frame(height: 180)
                        .padding(.vertical, 4)
                    
                    if let first = progress.history.first, let last = progress.history.last {
                        let firstVal = selectedMetric == .oneRM ? first.estimated1RM : first.maxWeight
                        let lastVal = selectedMetric == .oneRM ? last.estimated1RM : last.maxWeight
                        let delta = lastVal - firstVal
                        let deltaStr = delta >= 0 ? "+\(formatKg(delta)) kg" : "\(formatKg(delta)) kg"
                        Label(
                            L10n.t("较首次记录 \(deltaStr)", "\(deltaStr) vs. initial"),
                            systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right"
                        )
                        .font(Theme.Typography.caption)
                        .foregroundStyle(delta >= 0 ? Theme.Colors.ember : Theme.Colors.textMuted)
                    }
                } else {
                    Text(L10n.t("至少两次训练记录后显示曲线", "Requires at least 2 logged workouts to show graph"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            .listRowBackground(Theme.Colors.surfaceRaised)

            // MARK: - Realistic Strength Standards & Tier Ladder
            Section {
                ExerciseStrengthStandardsView(
                    exercise: exercise,
                    user1RM: best1RM
                )
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.surfaceBase.ignoresSafeArea())
        .navigationTitle(exercise.primaryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(exercise.primaryName).font(Theme.Typography.cardTitle).foregroundStyle(Theme.Colors.textPrimary)
                    Text(exercise.secondaryName).font(Theme.Typography.caption).foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
        .sheet(isPresented: $showDetailedGuide) {
            NavigationStack {
                DetailedExerciseGuideView(exercise: exercise)
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

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// History chart supporting toggle between Est. 1RM and Max Weight.
struct StrengthHistoryChart: View {
    let points: [StrengthHistoryPoint]
    var metric: ChartMetric = .oneRM

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value(L10n.t("日期", "Date"), point.date, unit: .day),
                y: .value(metric.displayName, yValue(for: point))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Theme.Colors.ember)

            PointMark(
                x: .value(L10n.t("日期", "Date"), point.date, unit: .day),
                y: .value(metric.displayName, yValue(for: point))
            )
            .foregroundStyle(Theme.Colors.ember)
            .symbolSize(24)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.Colors.borderHairline)
                AxisValueLabel()
                    .foregroundStyle(Theme.Colors.textMuted)
                    .font(Theme.Typography.caption)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel(format: .dateTime.month().day())
                    .foregroundStyle(Theme.Colors.textMuted)
                    .font(Theme.Typography.caption)
            }
        }
    }

    private func yValue(for point: StrengthHistoryPoint) -> Double {
        metric == .oneRM ? point.estimated1RM : point.maxWeight
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map { yValue(for: $0) }
        let lo = (values.min() ?? 0) * 0.95
        let hi = max((values.max() ?? 1) * 1.05, lo + 1)
        return lo...hi
    }
}
