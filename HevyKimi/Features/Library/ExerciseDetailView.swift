import SwiftUI

/// Exercise detail: bilingual name, muscle group, equipment, instructions.
/// PR history and est-1RM chart for this exercise arrive in steps 4/6.
struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        List {
            Section {
                LabeledContent("主要肌群", value: exercise.primaryMuscle.displayName)
                LabeledContent("器械", value: exercise.equipment.displayName)
                LabeledContent("类型", value: exercise.isCompound ? "复合动作" : "孤立动作")
            }

            if let instructions = exercise.instructions, !instructions.isEmpty {
                Section("动作要领") {
                    Text(instructions)
                        .font(.body)
                }
            }

            // Step 4/6: personal best + progress chart for this exercise
            Section {
                Label("完成力量标准后，这里会显示你的历史最好成绩与进步曲线", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(exercise.nameZh)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(exercise.nameZh).font(.headline)
                    Text(exercise.nameEn).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
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
            instructions: "仰卧于卧推凳，握距略宽于肩。"
        ))
        .preferredColorScheme(.dark)
    }
}
