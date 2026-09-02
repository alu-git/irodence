import SwiftUI

/// Exercise library view with persistent search bar, sticky muscle group filter chips,
/// equipment filter, and flexible sort modes.
struct ExerciseLibraryView: View {
    @EnvironmentObject private var service: ExerciseService
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @State private var query = ""
    @State private var selectedMuscle: MuscleGroup? = nil

    // Filtered exercise list
    private var filtered: [Exercise] {
        var result = service.exercises

        if let mg = selectedMuscle {
            result = result.filter { $0.primaryMuscle == mg }
        }

        if !query.isEmpty {
            let q = query.lowercased()
            result = result.filter {
                $0.nameZh.contains(query) || $0.nameEn.lowercased().contains(q)
            }
        }

        return result
    }

    // Filtered & grouped by muscle group
    private var filteredGrouped: [(muscle: MuscleGroup, exercises: [Exercise])] {
        let items = filtered
        let groups = Dictionary(grouping: items, by: { $0.primaryMuscle })
        return MuscleGroup.allCases.compactMap { mg in
            guard let list = groups[mg], !list.isEmpty else { return nil }
            return (muscle: mg, exercises: list.sorted { $0.primaryName < $1.primaryName })
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - 1. Persistent Search Bar
                searchHeader

                // MARK: - 2. Muscle Filter Chips Bar (Locked strictly to horizontal scroll)
                MuscleFilterBar(selected: $selectedMuscle)

                Divider()
                    .background(Theme.Colors.borderHairline)

                // MARK: - 3. Exercise List Content
                listContent
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("动作库", "Exercise Library"))
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await service.reload() }
            .task { await service.loadIfNeeded() }
        }
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textMuted)

            TextField(L10n.t("搜索动作（中/英文）…", "Search exercises (English / Chinese)…"), text: $query)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.xs)
        .background(Theme.Colors.surfaceBase)
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        if service.isLoading && service.exercises.isEmpty {
            VStack {
                Spacer()
                GymLoadingView(L10n.t("加载动作库中…", "Loading exercises…"))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.surfaceBase)
        } else if filtered.isEmpty {
            VStack(spacing: Theme.Spacing.sm) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.Colors.textMuted)
                Text(L10n.t("没有找到相关动作", "No matching exercises"))
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(L10n.t("尝试清除关键词或切换肌群筛选", "Try clearing search keyword or muscle filters"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                Button(L10n.t("重置筛选", "Reset Filters")) {
                    withAnimation {
                        query = ""
                        selectedMuscle = nil
                    }
                }
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.ember)
                .padding(.horizontal, Theme.Spacing.base)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.xs)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.surfaceBase)
        } else if query.isEmpty {
            List {
                ForEach(filteredGrouped, id: \.muscle) { group in
                    Section {
                        ForEach(group.exercises) { exercise in
                            ExerciseRow(exercise: exercise)
                        }
                    } header: {
                        Text(group.muscle.displayName)
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .listRowBackground(Theme.Colors.surfaceRaised)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surfaceBase)
        } else {
            List(filtered) { exercise in
                ExerciseRow(exercise: exercise)
                    .listRowBackground(Theme.Colors.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.surfaceBase)
        }
    }
}

// MARK: - Muscle filter chip bar

struct MuscleFilterBar: View {
    @Binding var selected: MuscleGroup?
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    var body: some View {
        if #available(iOS 16.4, *) {
            chipScrollContent
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {
            chipScrollContent
        }
    }

    private var chipScrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                // "All" chip
                FilterChip(
                    label: L10n.t("全部", "All"),
                    systemImage: "square.grid.2x2.fill",
                    muscleGroup: nil,
                    isSelected: selected == nil
                ) {
                    selected = nil
                }

                ForEach(MuscleGroup.allCases, id: \.self) { mg in
                    FilterChip(
                        label: mg.displayName,
                        systemImage: nil,
                        muscleGroup: mg,
                        isSelected: selected == mg
                    ) {
                        selected = (selected == mg) ? nil : mg
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .frame(height: 48)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.Colors.surfaceBase)
    }
}

// MARK: - Individual chip

struct FilterChip: View {
    let label: String
    let systemImage: String?
    let muscleGroup: MuscleGroup?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let muscleGroup {
                    MiniMuscleDiagram(
                        primary: muscleGroup.anatomicalMuscles,
                        highlightColor: isSelected ? Theme.Colors.emberDeep : Theme.Colors.ember,
                        inactiveColor: isSelected ? Theme.Colors.emberDeep.opacity(0.35) : Theme.Colors.textMuted.opacity(0.5),
                        outlineColor: isSelected ? Theme.Colors.emberDeep.opacity(0.5) : Theme.Colors.borderMetal
                    )
                    .frame(width: 14, height: 18)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(Theme.Typography.caption)
                }

                Text(label)
                    .font(Theme.Typography.label)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .padding(.horizontal, Theme.Spacing.base)
            .padding(.vertical, Theme.Spacing.xs * 1.5)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.pill)
                    .fill(isSelected ? Theme.Colors.ember : Theme.Colors.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.pill)
                    .strokeBorder(isSelected ? Color.clear : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
            )
            .foregroundStyle(isSelected ? Theme.Colors.emberDeep : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise row

struct ExerciseRow: View {
    let exercise: Exercise
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    var body: some View {
        NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.primaryName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(exercise.secondaryName)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                HStack(spacing: 6) {
                    if exercise.isCompound {
                        Text(L10n.t("复合", "Compound"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Colors.ember)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                    }

                    Text(exercise.equipment.displayName)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                }
            }
            .padding(.vertical, 4)
        }
    }
}
