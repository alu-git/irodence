import SwiftUI

/// Redesigned Forge Template Library featuring category tabs, live search,
/// exercise chip previews, interactive blueprint sheets, and home-screen favoriting.
struct TemplateLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var manager: WorkoutManager
    @EnvironmentObject private var library: ExerciseService
    @ObservedObject private var favoritesManager = FavoriteTemplatesManager.shared

    @State private var selectedCategory: TemplateCategory = .all
    @State private var searchText = ""
    @State private var previewTemplate: BuiltInTemplate?

    private var filteredTemplates: [BuiltInTemplate] {
        BuiltInTemplate.all.filter { template in
            // Category filter
            if selectedCategory != .all && template.category != selectedCategory {
                return false
            }
            // Search query
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let query = searchText.lowercased()
                let matchName = template.zhName.lowercased().contains(query) || template.enName.lowercased().contains(query)
                let matchSubtitle = template.zhSubtitle.lowercased().contains(query) || template.enSubtitle.lowercased().contains(query)
                let matchExercises = template.items.contains { $0.nameZh.lowercased().contains(query) || $0.nameEn.lowercased().contains(query) }
                let matchMuscles = template.targetMuscles.contains { $0.displayName.lowercased().contains(query) }
                return matchName || matchSubtitle || matchExercises || matchMuscles
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. Search Bar
                    searchBarView
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    // 2. Category Filter Chip Bar
                    categoryChipsBar
                        .padding(.bottom, 10)

                    // 3. Template Cards List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Header stats row
                            HStack {
                                Text(L10n.t("经典锻造图纸库", "Forge Blueprints & Routines"))
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)

                                Spacer()

                                Text(L10n.t("共 \(filteredTemplates.count) 套", "\(filteredTemplates.count) Templates"))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.Colors.surfaceRaised, in: Capsule())
                            }
                            .padding(.horizontal, 2)
                            .padding(.top, 6)
                            .padding(.bottom, 2)

                            if filteredTemplates.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(filteredTemplates) { template in
                                    templateCard(template)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, 36)
                    }
                }
            }
            .navigationTitle(L10n.t("图纸库", "Template Library"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .sheet(item: $previewTemplate) { template in
                TemplatePreviewSheet(template: template) {
                    dismiss()
                    Task {
                        await library.loadIfNeeded()
                        await manager.startBuiltIn(template, library: library)
                    }
                }
            }
        }
    }

    // MARK: - 1. Search Bar

    private var searchBarView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Colors.textMuted)

            TextField(L10n.t("搜索模板、动作或肌群 (如：推力、卧推、背)…", "Search templates, lifts, muscles…"), text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 2. Category Chips Bar

    private var categoryChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TemplateCategory.allCases) { cat in
                    let isSelected = selectedCategory == cat
                    Button {
                        selectedCategory = cat
                        ForgeHaptics.selection()
                    } label: {
                        Text(cat.displayName)
                            .font(.system(size: 13.5, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Theme.Colors.emberDeep : Theme.Colors.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Theme.Colors.ember : Theme.Colors.surfaceRaised,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    // MARK: - 3. Template Card

    private func templateCard(_ template: BuiltInTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Top Row: Category + Duration + Spacer + Star + Quick Start Button
            HStack(alignment: .center, spacing: 8) {
                Text(template.category.displayName)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 10.5))
                    Text(L10n.t("\(template.estimatedMinutes) 分钟", "\(template.estimatedMinutes)m"))
                        .font(.system(size: 11.5, weight: .medium))
                }
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))

                Spacer()

                // Star Favorite Button
                Button {
                    favoritesManager.toggleFavorite(id: template.id)
                    ForgeHaptics.selection()
                } label: {
                    Image(systemName: favoritesManager.isFavorite(id: template.id) ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(favoritesManager.isFavorite(id: template.id) ? Theme.Colors.ember : Theme.Colors.textMuted)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Quick Start Button
                Button {
                    dismiss()
                    Task {
                        await library.loadIfNeeded()
                        await manager.startBuiltIn(template, library: library)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(L10n.t("开练", "Start"))
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.ember, in: Capsule())
                }
                .buttonStyle(.forgePress)
            }

            // Title
            Text(template.name)
                .font(.system(size: 17.5, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            // Exercise Pills Strip Preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(template.items.prefix(4)) { item in
                        Text(item.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                    }
                    if template.items.count > 4 {
                        Text("+\(template.items.count - 4)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .onTapGesture {
            previewTemplate = template
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textMuted)
                .padding(.top, 40)

            Text(L10n.t("未找到相关图纸", "No Blueprints Found"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(L10n.t("换个关键词或分类筛选试试", "Try changing keywords or category filters"))
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}
