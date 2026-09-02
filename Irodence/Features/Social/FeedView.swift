import SwiftUI

/// Push destinations shared by the feed, workout detail, and user profile.
enum FeedDestination: Hashable {
    case workout(FeedItem)
    case profile(userID: UUID, displayName: String)
}

/// 动态 feed: finished workouts from you + people you follow (Hevy-style),
/// with likes and comments. Data comes from the `workout_feed` view via FeedService.
struct FeedListView: View {
    @StateObject private var service: FeedService
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    private let viewerID: UUID
    private let viewerName: String

    init(userID: UUID, displayName: String = "") {
        _service = StateObject(wrappedValue: FeedService(userID: userID))
        self.viewerID = userID
        self.viewerName = displayName
    }

    var body: some View {
        Group {
            if service.isLoading {
                GymLoadingView(L10n.t("加载动态中…", "Loading activity…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if service.items.isEmpty {
                ComingSoonView(
                    title: L10n.t("还没有动态", "No Activity Yet"),
                    systemImage: "figure.strengthtraining.traditional",
                    subtitle: L10n.t("关注好友后，他们的训练会出现在这里", "Workouts from people you follow will appear here")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(service.items) { item in
                            FeedCardView(
                                item: item,
                                viewerID: viewerID,
                                viewerName: viewerName,
                                onLike: { Task { await service.toggleLike(item) } }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .refreshable { await service.load() }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: FeedDestination.self) { destination in
            switch destination {
            case .workout(let item):
                WorkoutDetailView(item: item)
            case .profile(let userID, let displayName):
                UserProfileView(userID: userID, displayName: displayName,
                                viewerID: service.viewerID)
            }
        }
        .task { await service.load() }
    }
}

/// One workout card: tappable profile header, title, stats, the first three
/// exercises with their numbers + a mini muscle diagram, a "+N more" row,
/// and like + comment buttons. The whole card pushes the expanded workout detail.
struct FeedCardView: View {
    let item: FeedItem
    let viewerID: UUID
    let viewerName: String
    let onLike: () -> Void
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @State private var showComments = false

    /// Exercises previewed on the card; the rest collapse into "+N 个动作".
    private static let previewCount = 3

    var body: some View {
        NavigationLink(value: FeedDestination.workout(item)) {
            VStack(alignment: .leading, spacing: 12) {
                header
                titleAndStats
                if !item.exercises.isEmpty {
                    Divider()
                    exercisePreview
                }
                Divider()
                footer
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showComments) {
            CommentsSheet(item: item, viewerID: viewerID, viewerName: viewerName)
        }
    }

    // MARK: - Sections

    /// Avatar + name tap through to the person's profile.
    private var header: some View {
        NavigationLink(value: FeedDestination.profile(userID: item.userID,
                                                      displayName: item.displayName)) {
            HStack(spacing: 10) {
                AvatarView(name: item.displayName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.relativeTimeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var titleAndStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name).font(.headline)
            HStack(spacing: 16) {
                Label(item.durationText, systemImage: "clock")
                Label(item.volumeText, systemImage: "scalemass")
                Label("\(item.setCount)", systemImage: "checkmark.circle")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
    }

    /// First three exercises with a muscle thumbnail and their numbers.
    private var exercisePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(item.exercises.prefix(Self.previewCount)) { exercise in
                ExercisePreviewRow(exercise: exercise)
            }
            if item.exerciseCount > Self.previewCount {
                Text("+\(item.exerciseCount - Self.previewCount) \(L10n.t("个动作", "more exercises"))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            // Like button
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: item.likedByMe ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundStyle(item.likedByMe ? Color.accentColor : Color.secondary)
                        .scaleEffect(item.likedByMe ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: item.likedByMe)
                    if item.likeCount > 0 {
                        Text("\(item.likeCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Comment button
            Button {
                showComments = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    if item.commentCount > 0 {
                        Text("\(item.commentCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

/// Exercise row used on feed cards: mini muscle diagram + name + numbers.
struct ExercisePreviewRow: View {
    let exercise: FeedExerciseSummary
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    var body: some View {
        HStack(spacing: 10) {
            MiniMuscleDiagram(primary: exercise.muscles.primary,
                              secondary: exercise.muscles.secondary)
                .frame(width: 28, height: 36)
                .clipped()
            Text(exercise.displayName)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Text(exercise.compactNumbersText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Circle with the person's initial — placeholder until real avatars land.
struct AvatarView: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Color.accentColor.opacity(0.15))
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: size, height: size)
    }
}
