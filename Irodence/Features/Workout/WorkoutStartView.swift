import SwiftUI

/// Idle state of the training tab: start empty, or start from a template.
struct WorkoutStartView: View {
    @EnvironmentObject private var manager: WorkoutManager
    @EnvironmentObject private var library: ExerciseService

    @State private var templates: [(template: WorkoutTemplate, exercises: [WorkoutTemplateExercise])] = []
    @State private var isLoadingTemplates = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await manager.startEmpty() }
                    } label: {
                        Label("开始自由训练", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listRowBackground(Color.clear)

                Section("推荐模板") {
                    ForEach(BuiltInTemplate.all) { template in
                        Button {
                            Task {
                                await library.loadIfNeeded()
                                await manager.startBuiltIn(template, library: library)
                            }
                        } label: {
                            HStack {
                                Image(systemName: template.systemImage)
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading) {
                                    Text(template.name).font(.headline)
                                    Text("\(template.subtitle) · \(template.items.count) 个动作")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                }

                Section("模板") {
                    if isLoadingTemplates {
                        ProgressView()
                    } else if templates.isEmpty {
                        Text("还没有模板。完成一次训练后可以保存为模板。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(templates, id: \.template.id) { item in
                            Button {
                                Task {
                                    await manager.start(
                                        from: item.template,
                                        templateExercises: item.exercises,
                                        library: library
                                    )
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading) {
                                        Text(item.template.name).font(.headline)
                                        Text("\(item.exercises.count) 个动作")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .tint(.primary)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task {
                                        try? await WorkoutService().deleteTemplate(item.template.id)
                                        await loadTemplates()
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if let error = manager.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("训练")
            .task { await loadTemplates() }
        }
    }

    private func loadTemplates() async {
        let userID = manager.userIDForTemplates
        isLoadingTemplates = true
        defer { isLoadingTemplates = false }
        templates = (try? await WorkoutService().fetchTemplates(userID: userID)) ?? []
    }
}
