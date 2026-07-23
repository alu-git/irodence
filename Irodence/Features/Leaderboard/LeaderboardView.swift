import SwiftUI

/// Leaderboard tab: strength board (per lift, est 1RM or DOTS) and the
/// weekly volume board. Each supports 全球 / 好友 scope.
struct LeaderboardView: View {
    @EnvironmentObject private var library: ExerciseService
    @StateObject private var service: SocialService

    @State private var board: Board = .strength
    @State private var lift: CoreLift = .squat
    @State private var scope: Scope = .global
    @State private var sort: StrengthSort = .dots
    @State private var showFriendSearch = false

    enum Board: String, CaseIterable {
        case strength, volume
        var displayName: String {
            switch self {
            case .strength: return "力量榜"
            case .volume: return "周容量榜"
            }
        }
    }

    enum Scope: String, CaseIterable {
        case global, friends
        var displayName: String {
            switch self {
            case .global: return "全球"
            case .friends: return "好友"
            }
        }
    }

    enum StrengthSort: String, CaseIterable {
        case dots, oneRM
        var displayName: String {
            switch self {
            case .dots: return "DOTS"
            case .oneRM: return "1RM"
            }
        }
    }

    init(userID: UUID) {
        _service = StateObject(wrappedValue: SocialService(userID: userID))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("榜单", selection: $board) {
                    ForEach(Board.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                controls

                if board == .strength {
                    strengthList
                } else {
                    volumeList
                }
            }
            .navigationTitle("排行榜")
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
                FriendSearchView(service: service)
            }
            .task { await reload() }
            .onChange(of: lift) { _ in Task { await reload() } }
            .onChange(of: board) { _ in Task { await reload() } }
            .refreshable { await reload() }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 8) {
            if board == .strength {
                Menu {
                    ForEach(CoreLift.allCases, id: \.self) { l in
                        Button(l.displayName) { lift = l }
                    }
                } label: {
                    Label(lift.displayName, systemImage: "dumbbell.fill")
                        .font(.subheadline.weight(.medium))
                }

                Menu {
                    ForEach(StrengthSort.allCases, id: \.self) { s in
                        Button(s.displayName) { sort = s }
                    }
                } label: {
                    Label(sort.displayName, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.medium))
                }
            }

            Spacer()

            Picker("范围", selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Strength board

    /// Filtered + sorted strength entries. Friends scope includes self.
    private var visibleEntries: [LeaderboardEntry] {
        var result = service.entries
        if scope == .friends {
            result = result.filter { service.followingIDs.contains($0.userID) || $0.userID == service.userID }
        }
        switch sort {
        case .oneRM:
            result.sort { $0.estimated1RM > $1.estimated1RM }
        case .dots:
            // Entries without DOTS (no sex/bodyweight set) sink to the bottom
            result.sort { ($0.dotsScore ?? -1) > ($1.dotsScore ?? -1) }
        }
        return result
    }

    private var strengthList: some View {
        Group {
            if service.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if visibleEntries.isEmpty {
                ComingSoonView(
                    title: scope == .friends ? "好友里还没有人上榜" : "还没有人上榜",
                    systemImage: "trophy",
                    subtitle: "完成训练并刷新纪录即可上榜"
                )
            } else {
                List(Array(visibleEntries.enumerated()), id: \.element.id) { rank, entry in
                    StrengthRowView(rank: rank + 1, entry: entry,
                                    isSelf: entry.userID == service.userID, sort: sort)
                }
            }
        }
    }

    // MARK: - Volume board

    private var visibleVolume: [WeeklyVolumeEntry] {
        var result = service.weeklyVolume
        if scope == .friends {
            result = result.filter { service.followingIDs.contains($0.userID) || $0.userID == service.userID }
        }
        return result
    }

    private var volumeList: some View {
        Group {
            if service.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if visibleVolume.isEmpty {
                ComingSoonView(title: "本周还没有训练记录", systemImage: "chart.bar",
                               subtitle: "完成一次训练即可上榜")
            } else {
                List(Array(visibleVolume.enumerated()), id: \.element.id) { rank, entry in
                    HStack {
                        RankBadge(rank: rank + 1)
                        Text(entry.displayName)
                            .font(.headline)
                            .fontWeight(entry.userID == service.userID ? .bold : .regular)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(formatVolume(entry.totalVolumeKg)) kg")
                                .font(.headline.monospacedDigit())
                            Text("\(entry.totalSets) 组")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func formatVolume(_ kg: Double) -> String {
        kg >= 10000 ? String(format: "%.1fk", kg / 1000) : String(Int(kg))
    }

    private func reload() async {
        await service.loadFollowing()
        switch board {
        case .strength:
            await library.loadIfNeeded()
            guard let exercise = library.exercises.first(where: { $0.nameEn == lift.exerciseNameEn }) else { return }
            await service.loadLeaderboard(exerciseID: exercise.id)
        case .volume:
            await service.loadWeeklyVolume()
        }
    }
}

// MARK: - Rows

private struct StrengthRowView: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isSelf: Bool
    let sort: LeaderboardView.StrengthSort

    var body: some View {
        HStack {
            RankBadge(rank: rank)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.headline)
                    .fontWeight(isSelf ? .bold : .regular)
                HStack(spacing: 8) {
                    Text("\(formatKg(entry.weightKg))×\(entry.reps)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let tier = entry.tier {
                        Text(tier.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tier.color)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sort == .dots ? dotsText : oneRMText)
                    .font(.headline.monospacedDigit())
                Text(sort == .dots ? "DOTS" : "1RM (kg)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dotsText: String {
        entry.dotsScore.map { String(format: "%.0f", $0) } ?? "—"
    }

    private var oneRMText: String {
        formatKg(entry.estimated1RM)
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

private struct RankBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.subheadline.monospacedDigit().weight(.bold))
            .foregroundStyle(rank <= 3 ? Color.yellow : Color.secondary)
            .frame(width: 28)
    }
}
