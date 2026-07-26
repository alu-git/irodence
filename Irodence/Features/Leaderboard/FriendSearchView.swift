import SwiftUI

/// Search users by display name and follow/unfollow them. With an empty
/// query, shows recommended users (most active this week) instead.
struct FriendSearchView: View {
    @ObservedObject var service: SocialService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    if !service.recommendations.isEmpty {
                        Section {
                            ForEach(service.recommendations) { profile in
                                row(for: profile)
                            }
                        } header: {
                            Text("推荐好友")
                        } footer: {
                            Text("本周最活跃的小伙伴")
                        }
                    }
                } else {
                    ForEach(service.searchResults) { profile in
                        row(for: profile)
                    }
                }
            }
            .overlay {
                if !query.isEmpty && service.searchResults.isEmpty {
                    ComingSoonView(title: "没有找到「\(query)」", systemImage: "magnifyingglass",
                                   subtitle: "换个名字试试")
                } else if query.isEmpty && service.recommendations.isEmpty {
                    ComingSoonView(title: "搜索好友", systemImage: "person.2",
                                   subtitle: "输入昵称查找并关注")
                }
            }
            .navigationTitle("添加好友")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "搜索昵称")
            .onChange(of: query) { newValue in
                Task { await service.searchUsers(query: newValue) }
            }
            .task {
                await service.loadFollowing()
                await service.loadRecommendations()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for profile: Profile) -> some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(profile.displayName).font(.headline)
            Spacer()
            if profile.id != service.userID {
                if service.followingIDs.contains(profile.id) {
                    Button("已关注") {
                        Task { await service.unfollow(profile.id) }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("关注") {
                        Task { await service.follow(profile.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
