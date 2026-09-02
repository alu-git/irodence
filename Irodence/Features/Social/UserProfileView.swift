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
    @State private var userCrewName: String = "玄铁重工"
    @State private var showCrewDetail = false

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

                // Team / Crew Belonging Card
                teamBelongingCard

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
                            FeedCardView(
                                item: item,
                                viewerID: viewerID,
                                viewerName: displayName,
                                onLike: { Task { await feed.toggleLike(item) } }
                            )
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

    private var teamBelongingCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.ember.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(L10n.t("所属熔炉战队", "Belonging Crew"))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)

                    Text(L10n.t("已点火", "Ignited"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Colors.ember)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Theme.Colors.ember.opacity(0.12), in: Capsule())
                }

                Text(userCrewName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Spacer()

            Text(L10n.t("同炉铁友", "Crewmate"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.ember)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.surfaceRaised, in: Capsule())
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
        // Determine crew name deterministically if joined
        if displayName.contains("麦昆") {
            userCrewName = L10n.t("闪电车队", "Lightning Squad")
        } else if displayName.contains("水手") {
            userCrewName = L10n.t("大力菠菜营", "Popeye Camp")
        } else {
            userCrewName = L10n.t("玄铁重工", "Dark Iron Forge")
        }
    }
}
