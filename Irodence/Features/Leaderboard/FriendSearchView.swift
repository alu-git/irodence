import SwiftUI

/// Community Discovery & Recommendations view.
/// Shows featured crews, trending tags, and recommended lifters when query is empty.
struct FriendSearchView: View {
    @ObservedObject var service: SocialService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @State private var query = ""
    @State private var selectedTag: String? = nil

    private let communityTags = [
        "#练后泵感", "#推力日打卡", "#三大项突破",
        "#晨练铁友", "#硬核营养", "#力量举", "#玄铁重工"
    ]

    private struct FeaturedCrewItem: Identifiable {
        let id = UUID()
        let name: String
        let slogan: String
        let membersCount: Int
        let weeklyTonnage: String
        let icon: String
    }

    private let featuredCrews: [FeaturedCrewItem] = [
        FeaturedCrewItem(
            name: "玄铁重工",
            slogan: "专注三大项硬核力量举 · 状态永不熄火",
            membersCount: 42,
            weeklyTonnage: "380k kg",
            icon: "flame.fill"
        ),
        FeaturedCrewItem(
            name: "闪电车队",
            slogan: "高频敏捷增肌 · 每日清晨6点开炉",
            membersCount: 28,
            weeklyTonnage: "250k kg",
            icon: "bolt.fill"
        ),
        FeaturedCrewItem(
            name: "大力菠菜营",
            slogan: "雕刻肌群线条 · 严格动作轨迹",
            membersCount: 35,
            weeklyTonnage: "290k kg",
            icon: "leaf.fill"
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // 1. Top Search Header
                        searchBar

                        if query.isEmpty {
                            // 2. Trending Community Tags
                            trendingTagsSection

                            // 3. Featured Crews Strip
                            featuredCrewsSection

                            // 4. Recommended Lifters
                            recommendedLiftersSection
                        } else {
                            // Search Results
                            searchResultsSection
                        }
                    }
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .navigationTitle(L10n.t("社区发现与好友", "Community & Friends"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("完成", "Done")) { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.ember)
                }
            }
            .task {
                await service.loadFollowing()
                await service.loadRecommendations()
            }
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Colors.textMuted)

            TextField(L10n.t("搜索铁友昵称、口号或战队…", "Search lifter, bio or crew…"), text: $query)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .onChange(of: query) { newValue in
                    Task { await service.searchUsers(query: newValue) }
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    Task { await service.searchUsers(query: "") }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
        .padding(12)
        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var trendingTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.ember)
                Text(L10n.t("社区热门打卡话题", "Trending Topics"))
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(communityTags, id: \.self) { tag in
                        let isSelected = selectedTag == tag
                        Button {
                            if isSelected {
                                selectedTag = nil
                                query = ""
                            } else {
                                selectedTag = tag
                                query = tag.replacingOccurrences(of: "#", with: "")
                            }
                        } label: {
                            Text(tag)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? Theme.Colors.textOnEmber : Theme.Colors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected ? Theme.Colors.ember : Theme.Colors.surfaceRaised,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isSelected ? Color.clear : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    private var featuredCrewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("🛡️ 社区推荐战队", "🛡️ Featured Crews"))
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredCrews) { crew in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: crew.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Colors.ember)
                                Text(crew.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                            }

                            Text(crew.slogan)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .lineLimit(2)
                                .frame(height: 34, alignment: .topLeading)

                            Divider()
                                .background(Theme.Colors.borderHairline)

                            HStack {
                                Text("👥 \(crew.membersCount) 人")
                                Spacer()
                                Text("🏋️ \(crew.weeklyTonnage)")
                            }
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(12)
                        .frame(width: 220)
                        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    private var recommendedLiftersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("👥 铁馆达人推荐", "👥 Recommended Lifters"))
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(L10n.t("本周活跃榜", "Active this week"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(.horizontal, Theme.Spacing.md)

            VStack(spacing: 8) {
                ForEach(service.recommendations) { profile in
                    lifterCard(profile)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("搜索结果 (\(service.searchResults.count))", "Search Results (\(service.searchResults.count))"))
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)

            if service.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text(L10n.t("未找到匹配的铁友", "No Lifters Found"))
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(L10n.t("尝试搜索其他昵称或战队关键词", "Try searching another username or keyword"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(service.searchResults) { profile in
                        lifterCard(profile)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
            }
        }
    }

    private func lifterCard(_ profile: Profile) -> some View {
        let isFollowing = service.followingIDs.contains(profile.id)
        let crewName = crewNameFor(profile.id)

        return HStack(spacing: 12) {
            AvatarView(name: profile.displayName, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    if let crew = crewName {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8.5))
                            Text(crew)
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.ember)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.ember.opacity(0.12), in: Capsule())
                    }
                }

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let bw = profile.bodyweightKg {
                        Text("🏋️ \(Int(bw))kg")
                    }
                    if let height = profile.heightCm {
                        Text("📏 \(Int(height))cm")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.textMuted)
            }

            Spacer()

            if profile.id != service.userID {
                Button {
                    ForgeHaptics.strike()
                    Task {
                        if isFollowing {
                            await service.unfollow(profile.id)
                        } else {
                            await service.follow(profile.id)
                        }
                    }
                } label: {
                    Text(isFollowing ? L10n.t("已关注", "Following") : L10n.t("+ 关注", "+ Follow"))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(isFollowing ? Theme.Colors.textSecondary : Theme.Colors.textOnEmber)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            isFollowing ? Theme.Colors.surfaceSunken : Theme.Colors.ember,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(isFollowing ? Theme.Colors.borderMetal : Color.clear, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    private func crewNameFor(_ id: UUID) -> String? {
        let idStr = id.uuidString
        if idStr.hasSuffix("01") || idStr.hasSuffix("04") {
            return "玄铁重工"
        } else if idStr.hasSuffix("02") || idStr.hasSuffix("05") {
            return "闪电车队"
        } else if idStr.hasSuffix("03") || idStr.hasSuffix("06") {
            return "大力菠菜营"
        }
        return nil
    }
}
