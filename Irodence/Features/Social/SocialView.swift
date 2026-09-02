import SwiftUI

/// Social tab: 动态 feed (friends' workouts) + the leaderboards, sharing one
/// SocialService so follows made in search reflect on the boards instantly.
struct SocialView: View {
    @EnvironmentObject private var library: ExerciseService
    @StateObject private var social: SocialService
    @State private var tab: SocialTab = .feed
    @State private var showFriendSearch = false

    private let userID: UUID

    enum SocialTab: String, CaseIterable {
        case feed, boards
        var displayName: String {
            switch self {
            case .feed: return L10n.t("动态", "Feed")
            case .boards: return L10n.t("排行榜", "Leaderboard")
            }
        }
    }

    init(userID: UUID) {
        self.userID = userID
        _social = StateObject(wrappedValue: SocialService(userID: userID))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker(L10n.t("视图", "View"), selection: $tab) {
                    ForEach(SocialTab.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    switch tab {
                    case .feed:
                        FeedListView(userID: userID)
                    case .boards:
                        LeaderboardBoardsView(service: social)
                            .environmentObject(library)
                    }
                }
                // Pin the picker to the top: force the content region to
                // claim all leftover height so a small empty-state child
                // can't center the whole VStack (and the picker with it)
                // in the middle of the screen.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle(L10n.t("社交", "Social"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFriendSearch = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showFriendSearch) {
                FriendSearchView(service: social)
            }
        }
    }
}
