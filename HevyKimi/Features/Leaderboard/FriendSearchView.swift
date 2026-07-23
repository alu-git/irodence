import SwiftUI

/// Search users by display name and follow/unfollow them.
struct FriendSearchView: View {
    @ObservedObject var service: SocialService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(service.searchResults) { profile in
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
            .overlay {
                if !query.isEmpty && service.searchResults.isEmpty {
                    ComingSoonView(title: "没有找到「\(query)」", systemImage: "magnifyingglass",
                                   subtitle: "换个名字试试")
                } else if query.isEmpty {
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
