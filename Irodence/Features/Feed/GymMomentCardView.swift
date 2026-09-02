import SwiftUI
import UIKit

/// Visual card for casual gym moments (泵感日常 / 铁馆打卡).
struct GymMomentCardView: View {
    let moment: GymMoment
    let currentUserID: UUID
    let onFistBump: () -> Void
    let onFire: () -> Void

    @State private var showCommentsSheet = false
    @State private var commentCount: Int

    init(moment: GymMoment, currentUserID: UUID, onFistBump: @escaping () -> Void, onFire: @escaping () -> Void) {
        self.moment = moment
        self.currentUserID = currentUserID
        self.onFistBump = onFistBump
        self.onFire = onFire
        _commentCount = State(initialValue: moment.commentCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // 1. Author Header (麦昆 · 熟铁 | 30 分钟前 · 🔒 仅熔炉可见)
            headerRow

            // 2. Photo / Image Container
            mediaContainer

            // 3. Caption & Workout Summary Stats
            VStack(alignment: .leading, spacing: 6) {
                if let caption = moment.caption, !caption.isEmpty {
                    Text(caption)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineSpacing(3)
                }

                // Workout Stat Line (推力日 · 1h 15m · 容量 8.4t)
                workoutStatsLine
            }

            // 4. Action Row (🤘 碰拳/致敬 | 💬 熔炉评论)
            actionRow
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
        .sheet(isPresented: $showCommentsSheet) {
            CommentsSheet(
                targetID: moment.id,
                title: L10n.t("\(moment.userDisplayName) 的日常", "\(moment.userDisplayName)'s Moment"),
                viewerID: currentUserID,
                viewerName: L10n.t("铁友", "Lifter")
            )
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AvatarView(name: moment.userDisplayName, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                // Name + Tier (麦昆 · 熟铁)
                HStack(spacing: 4) {
                    Text(moment.userDisplayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    if let tier = moment.userTierName, !tier.isEmpty {
                        Text("· \(tier)")
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                }

                // Subtitle (30 分钟前 · 🔒 仅熔炉可见)
                HStack(spacing: 5) {
                    Text(timeAgoDisplay(moment.createdAt))

                    Text("·")

                    Image(systemName: moment.visibilityText == "社区公开" ? "globe.asia.australia.fill" : "lock.fill")
                        .font(.system(size: 9))

                    Text(moment.visibilityText ?? L10n.t("仅熔炉可见", "Crew Only"))
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textMuted)
            }

            Spacer()
        }
    }

    private var mediaContainer: some View {
        Group {
            if let data = moment.localImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            } else {
                // Sleek dark sunken photo placeholder matching reference
                ZStack {
                    Theme.Colors.surfaceSunken

                    Image(systemName: "photo")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.Colors.textMuted.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
        }
    }

    private var workoutStatsLine: some View {
        let name = moment.workoutName ?? L10n.t("推力日", "Push Day")
        let duration = moment.workoutDurationText ?? "1h 15m"
        let volume = moment.workoutVolumeText ?? "容量 8.4t"

        return Text("\(name) · \(duration) · \(volume)")
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.textMuted)
    }

    private var actionRow: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // 碰拳 / 致敬 (Lifter Strike / Bump)
            Button {
                onFistBump()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: moment.fistBumpedByMe ? "hand.raised.fingers.spread.fill" : "hand.raised.fingers.spread")
                        .font(.system(size: 14))
                        .foregroundStyle(moment.fistBumpedByMe ? Theme.Colors.ember : Theme.Colors.textSecondary)
                    Text("\(moment.fistBumpCount)")
                        .font(Theme.Typography.label)
                        .foregroundStyle(moment.fistBumpedByMe ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            // 💬 熔炉评论 (Comments)
            Button {
                showCommentsSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(L10n.t("熔炉 \(commentCount)", "Crew \(commentCount)"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 2)
    }

    private func timeAgoDisplay(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return L10n.t("刚刚", "Just now") }
        if diff < 3600 { return L10n.t("\(diff / 60)分钟前", "\(diff / 60)m ago") }
        if diff < 86400 { return L10n.t("\(diff / 3600)小时前", "\(diff / 3600)h ago") }
        return L10n.t("\(diff / 86400)天前", "\(diff / 86400)d ago")
    }
}
