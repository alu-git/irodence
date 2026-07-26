import SwiftUI

/// Exercise library — searchable list grouped by muscle group.
struct ExerciseLibraryView: View {
    @EnvironmentObject private var service: ExerciseService
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading && service.exercises.isEmpty {
                    ProgressView()
                } else if let error = service.errorMessage, service.exercises.isEmpty {
                    ComingSoonView(title: error, systemImage: "wifi.exclamationmark", subtitle: "下拉重试")
                } else if query.isEmpty {
                    groupedList
                } else {
                    searchResults
                }
            }
            .navigationTitle("动作库")
            .searchable(text: $query, prompt: "搜索动作（中/英文）")
            .refreshable { await service.reload() }
            .task { await service.loadIfNeeded() }
        }
    }

    private var groupedList: some View {
        List {
            ForEach(service.grouped, id: \.muscle) { group in
                Section(group.muscle.displayName) {
                    ForEach(group.exercises) { exercise in
                        ExerciseRow(exercise: exercise)
                    }
                }
            }
        }
    }

    private var searchResults: some View {
        List(service.search(query)) { exercise in
            ExerciseRow(exercise: exercise)
        }
        .overlay {
            if service.search(query).isEmpty {
                ComingSoonView(title: "没有找到「\(query)」", systemImage: "magnifyingglass", subtitle: "换个关键词试试")
            }
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.primaryName)
                        .font(.headline)
                    Text(exercise.secondaryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if exercise.isCompound {
                    Text("复合")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                }
                Text(exercise.equipment.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ExerciseLibraryView()
        .environmentObject(ExerciseService())
        .preferredColorScheme(.dark)
}
