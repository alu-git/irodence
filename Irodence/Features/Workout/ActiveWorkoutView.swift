import SwiftUI

/// Live workout logging screen: exercise cards, set entry, rest timer.
struct ActiveWorkoutView: View {
    @EnvironmentObject private var manager: WorkoutManager

    @State private var showExercisePicker = false
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false
    @State private var showTemplateNamePrompt = false
    @State private var templateName = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                exerciseList

                if manager.restEndsAt != nil {
                    RestTimerView(
                        restEndsAt: $manager.restEndsAt,
                        duration: $manager.restDurationSeconds
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: manager.restEndsAt != nil)
            .navigationTitle(manager.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(manager.name).font(.headline)
                        ElapsedTimeView(startedAt: manager.startedAt)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            templateName = manager.name
                            showTemplateNamePrompt = true
                        } label: {
                            Label("保存为模板", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            showDiscardConfirm = true
                        } label: {
                            Label("放弃训练", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showFinishConfirm = true }
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { selected in
                    Task {
                        for exercise in selected {
                            await manager.addExercise(exercise)
                        }
                    }
                }
            }
            .confirmationDialog("完成训练？", isPresented: $showFinishConfirm) {
                Button("完成并保存") {
                    Task {
                        let finished = await manager.finish()
                        if !finished, manager.errorMessage == nil {
                            showDiscardConfirm = true
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将保存本次训练并计算新纪录")
            }
            .confirmationDialog("放弃本次训练？", isPresented: $showDiscardConfirm) {
                Button("放弃并删除", role: .destructive) {
                    Task { await manager.discard() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("已记录的数据将被删除")
            }
            .alert("模板名称", isPresented: $showTemplateNamePrompt) {
                TextField("例如：推日", text: $templateName)
                Button("保存") {
                    Task { await manager.saveAsTemplate(templateName: templateName) }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(manager.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseCardView(exerciseIndex: index)
                }

                Button {
                    showExercisePicker = true
                } label: {
                    Label("添加动作", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                if let error = manager.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // Room for the rest-timer banner
                Color.clear.frame(height: 80)
            }
            .padding(.vertical)
        }
    }
}

/// Live-updating elapsed time in the nav bar.
private struct ElapsedTimeView: View {
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(format(context.date))
        }
    }

    private func format(_ now: Date) -> String {
        guard let startedAt else { return "" }
        let elapsed = Int(now.timeIntervalSince(startedAt))
        let h = elapsed / 3600, m = (elapsed % 3600) / 60, s = elapsed % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
