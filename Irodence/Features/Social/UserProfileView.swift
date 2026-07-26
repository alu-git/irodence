import SwiftUI
import Supabase

/// Another person's profile: avatar, basic stats, and their recent finished
/// workouts (same visibility rules as the feed — self + followees only).
struct UserProfileView: View {
    let userID: UUID
    let displayName: String
    let viewerID: UUID

    @StateObject private var feed: FeedService
    @State private var profile: Profile?

    init(userID: UUID, displayName: String, viewerID: UUID) {
        self.userID = userID
        self.displayName = displayName
        self.viewerID = viewerID
        _feed = StateObject(wrappedValue: FeedService(userID: viewerID))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileHeader

                if feed.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if feed.items.isEmpty {
                    ComingSoonView(
                        title: L10n.t("还没有公开的训练", "No workouts yet"),
                        systemImage: "figure.strengthtraining.traditional",
                        subtitle: L10n.t("完成的训练会显示在这里", "Finished workouts will show up here")
                    )
                    .padding(.top, 40)
                } else {
                    Text(L10n.t("最近的训练", "Recent workouts"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVStack(spacing: 12) {
                        ForEach(feed.items) { item in
                            FeedCardView(item: item) {
                                Task { await feed.toggleLike(item) }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadProfile()
            await feed.load(filterUserID: userID)
        }
        .refreshable {
            await loadProfile()
            await feed.load(filterUserID: userID)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            AvatarView(name: profile?.displayName ?? displayName, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(profile?.displayName ?? displayName)
                    .font(.title3.weight(.bold))
                HStack(spacing: 8) {
                    if let sex = profile?.sex {
                        chip(sex.displayName, icon: "person")
                    }
                    if let bw = profile?.bodyweightKg {
                        let text = bw.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(bw)) kg" : String(format: "%.1f kg", bw)
                        chip(text, icon: "scalemass")
                    }
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func chip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }

    private func loadProfile() async {
        profile = try? await SupabaseService.client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }
}
