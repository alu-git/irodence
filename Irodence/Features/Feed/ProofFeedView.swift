import SwiftUI

/// Main Feed (见证) Screen: Highest risk UI in Phase 3.
/// Features challenge invites (约战), proof list, witnessing hammer actions (验杠).
struct ProofFeedView: View {
    let userID: UUID

    enum FeedTab: Int, CaseIterable {
        case following = 0
        case community = 1
        case proofs = 2
        case moments = 3

        var title: String {
            switch self {
            case .following: return L10n.t("好友与我", "Friends & Me")
            case .community: return L10n.t("社区广场", "Community")
            case .proofs: return L10n.t("权威铁证", "Proofs")
            case .moments: return L10n.t("日常", "Daily")
            }
        }

        var icon: String {
            switch self {
            case .following: return "person.2.fill"
            case .community: return "globe.asia.australia.fill"
            case .proofs: return "shield.checkered"
            case .moments: return "flame.fill"
            }
        }
    }

    @State private var selectedTab: FeedTab = .following
    @StateObject private var proofService = ProofService()
    @StateObject private var challengeService = ChallengeService()
    @StateObject private var momentService = GymMomentService()
    @StateObject private var socialService: SocialService
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    @State private var showLeaderboard = false
    @State private var showFriendSearch = false
    @State private var showPublishSheet = false

    init(userID: UUID) {
        self.userID = userID
        _socialService = StateObject(wrappedValue: SocialService(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Feed Tabs (社区广场 / 关注好友 / 权威铁证 / 日常)
                    feedSegmentedBar

                    switch selectedTab {
                    case .community:
                        communityFeedSection
                    case .following:
                        followingFeedSection
                    case .proofs:
                        proofsFeedSection
                    case .moments:
                        momentsFeedSection
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("见证", "Feed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showLeaderboard = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy")
                                .font(.system(size: 13, weight: .semibold))
                            Text(L10n.t("锻造榜", "Leaderboard"))
                                .font(Theme.Typography.label)
                        }
                        .foregroundStyle(Theme.Colors.ember)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFriendSearch = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
            }
            .refreshable {
                await proofService.fetchFeed()
                await challengeService.fetchChallenges(userID: userID)
                await momentService.fetchMoments()
                await socialService.loadFollowing()
            }
            .task {
                await proofService.fetchFeed()
                await challengeService.fetchChallenges(userID: userID)
                await momentService.fetchMoments()
                await socialService.loadFollowing()
            }
            .sheet(isPresented: $showLeaderboard) {
                NavigationStack {
                    LeaderboardBoardsView(service: socialService)
                        .navigationTitle(L10n.t("锻造榜", "Leaderboard"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(L10n.t("完成", "Done")) { showLeaderboard = false }
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                }
            }
            .sheet(isPresented: $showFriendSearch) {
                FriendSearchView(service: socialService)
            }
            .sheet(isPresented: $showPublishSheet) {
                PublishMomentSheet(
                    userID: userID,
                    userDisplayName: L10n.t("我", "Me"),
                    userCrewName: L10n.t("玄铁重工", "Dark Iron"),
                    onPublished: {
                        showPublishSheet = false
                    }
                )
            }
        }
    }

    // MARK: - Subviews

    private var feedSegmentedBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FeedTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11.5, weight: .bold))
                            Text(tab.title)
                                .font(Theme.Typography.label)
                        }
                        .foregroundStyle(selectedTab == tab ? Theme.Colors.textOnEmber : Theme.Colors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab ? Theme.Colors.ember : Theme.Colors.surfaceRaised,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(selectedTab == tab ? Color.clear : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // 1. Community Feed (社区广场 - 全网铁友动态)
    private var communityFeedSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Challenge Invites
            if !challengeService.incomingChallenges.isEmpty {
                ForEach(challengeService.incomingChallenges) { challenge in
                    challengeInviteRow(challenge)
                }
            }

            // Mixed Stream (Moments + Proofs)
            ForEach(momentService.moments) { moment in
                GymMomentCardView(
                    moment: moment,
                    currentUserID: userID,
                    onFistBump: { momentService.toggleFistBump(momentID: moment.id) },
                    onFire: { momentService.toggleFire(momentID: moment.id) }
                )
            }

            ForEach(proofService.proofs) { proof in
                proofCard(proof)
            }
        }
    }

    // Quick "My Check-In / Share Status" Bar
    private var myCheckInCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.surfaceSunken)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().strokeBorder(Theme.Colors.ember.opacity(0.6), lineWidth: 1.5)
                    )

                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.Colors.ember)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("我的训练动态 · 实时打卡", "My Status & Check-In"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(L10n.t("分享今日泵感与成绩，与好友共同见证", "Share your workout pump & proof with friends"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            Spacer()

            Button {
                showPublishSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text(L10n.t("发动态", "Post"))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.Colors.ember, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // 2. Following Feed (关注好友与自身)
    private var followingFeedSection: some View {
        let friendsMoments = momentService.moments.filter {
            $0.userID == userID ||
            $0.userID == UUID(uuidString: "00000000-0000-0000-0000-000000000009")! ||
            socialService.followingIDs.contains($0.userID)
        }
        let friendsProofs = proofService.proofs.filter {
            $0.userID == userID ||
            $0.userID == UUID(uuidString: "00000000-0000-0000-0000-000000000009")! ||
            socialService.followingIDs.contains($0.userID)
        }

        return VStack(spacing: Theme.Spacing.md) {
            myCheckInCard

            if friendsMoments.isEmpty && friendsProofs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 38))
                        .foregroundStyle(Theme.Colors.textMuted)

                    Text(L10n.t("暂无关注好友动态", "No Following Posts Yet"))
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(L10n.t("去社区发现关注铁馆达人，或邀请铁友加入战队，在此查看他们的训练与突破。", "Follow lifters or invite crew mates to see their moments here."))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button {
                        showFriendSearch = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                            Text(L10n.t("发现与关注铁友", "Find & Follow Friends"))
                        }
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textOnEmber)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.ember, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl * 1.5)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
            } else {
                ForEach(friendsMoments) { moment in
                    GymMomentCardView(
                        moment: moment,
                        currentUserID: userID,
                        onFistBump: { momentService.toggleFistBump(momentID: moment.id) },
                        onFire: { momentService.toggleFire(momentID: moment.id) }
                    )
                }

                ForEach(friendsProofs) { proof in
                    proofCard(proof)
                }
            }
        }
    }

    // 3. Proofs Section (权威铁证)
    private var proofsFeedSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if !challengeService.incomingChallenges.isEmpty {
                ForEach(challengeService.incomingChallenges) { challenge in
                    challengeInviteRow(challenge)
                }
            }

            if proofService.isLoading && proofService.proofs.isEmpty {
                ForgeLoadingView(L10n.t("熔铸见证中…", "Forging feed…"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xl * 2)
            } else if proofService.proofs.isEmpty {
                emptyProofsView
            } else {
                ForEach(proofService.proofs) { proof in
                    proofCard(proof)
                }
            }
        }
    }

    // 4. Moments Section (泵感日常)
    private var momentsFeedSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(momentService.moments) { moment in
                GymMomentCardView(
                    moment: moment,
                    currentUserID: userID,
                    onFistBump: { momentService.toggleFistBump(momentID: moment.id) },
                    onFire: { momentService.toggleFire(momentID: moment.id) }
                )
            }
        }
    }

    private func proofCard(_ proof: Proof) -> some View {
        ProofCardView(
            proof: proof,
            currentUserID: userID,
            onWitness: { action in
                Task {
                    try? await proofService.witnessProof(
                        proofID: proof.id,
                        witnessID: userID,
                        action: action
                    )
                }
            },
            onBlockOrReport: {
                Task {
                    await proofService.fetchFeed()
                }
            }
        )
    }

    private var emptyProofsView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "hammer")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Theme.Colors.textMuted)
            Text(L10n.t("暂无试举见证", "No Proofs Yet"))
                .font(Theme.Typography.cardTitle)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(L10n.t("好钢需人验。发一条动态，喊同炉铁友来验杠。", "Steel needs witnesses. Post a PR and invite your crew to verify."))
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl * 2)
    }

    private func challengeInviteRow(_ challenge: Challenge) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.fencing")
                .font(Theme.Typography.screenTitle)
                .foregroundStyle(Theme.Colors.ember)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("\(challenge.localizedChallengerName) 发起约战", "\(challenge.localizedChallengerName) invited a duel"))
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(L10n.t("力量分增幅对决", "Strength Score Duel"))
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Task {
                        try? await challengeService.respondToChallenge(challengeID: challenge.id, accept: true)
                        await challengeService.fetchChallenges(userID: userID)
                    }
                } label: {
                    Text(L10n.t("应战", "Accept"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.emberDeep)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.forgePress)

                Button {
                    Task {
                        try? await challengeService.respondToChallenge(challengeID: challenge.id, accept: false)
                        await challengeService.fetchChallenges(userID: userID)
                    }
                } label: {
                    Text(L10n.t("拒绝", "Decline"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.forgePress)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.ember.opacity(0.6), lineWidth: Theme.Border.hairline)
        )
    }
}
