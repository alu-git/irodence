import SwiftUI

/// A single Proof Card (证词卡片) presenting a PR attempt, video proof,
/// stamped certification status, witnessing action, and safety reporting menu.
struct ProofCardView: View {
    let proof: Proof
    let currentUserID: UUID
    let onWitness: (WitnessAction) -> Void
    var onBlockOrReport: (() -> Void)? = nil

    @State private var hasWitnessed = false
    @State private var presentedURL: IdentifiableURL? = nil
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showCommentsSheet = false
    @State private var liked = false
    @State private var likeCount = 0

    private let blockService = BlockService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header: Lifter Avatar + Display Name + Tier Stamp + Time + Ellipsis
            HStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.surfaceSunken)
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                    HStack(spacing: 6) {
                        Text(proof.userDisplayName ?? L10n.t("铁友", "Lifter"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        // Team / Crew Badge
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                            Text(crewNameFor(proof.userDisplayName))
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(Theme.Colors.ember)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.ember.opacity(0.12), in: Capsule())

                        if proof.visibility == .crewOnly {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }

                    Text(timeAgoDisplay(proof.achievedAt))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                // Tier Pill / Material Stamp
                let tierDisplay = StrengthTier(dbValue: proof.tier)?.displayName ?? proof.tier
                Text(tierDisplay)
                    .font(Theme.Typography.label)
                    .foregroundStyle(proof.isCertified ? Theme.Colors.textOnEmber : Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs / 2)
                    .background(
                        proof.isCertified ? Theme.Colors.ember : Theme.Colors.surfaceSunken,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                            .strokeBorder(proof.isCertified ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )

                // Safety Options Menu for non-self proofs
                if proof.userID != currentUserID {
                    Menu {
                        Button(role: .destructive) {
                            showReportSheet = true
                        } label: {
                            Label(L10n.t("举报违规 / 骚扰", "Report Violation / Harassment"), systemImage: "exclamationmark.shield.fill")
                        }

                        Button(role: .destructive) {
                            showBlockConfirmation = true
                        } label: {
                            Label(L10n.t("静默拉黑该用户", "Silently Block Lifter"), systemImage: "nosign")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                    }
                }
            }

            // Stat Numerals: Exercise Name, Weight, Reps, 力量分
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                    Text(proof.exerciseDisplayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(L10n.t("\(formatKg(proof.weightKg)) kg × \(proof.reps) 次", "\(formatKg(proof.weightKg)) kg × \(proof.reps) reps"))
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Theme.Spacing.xs / 2) {
                    Text(L10n.t("力量分", "DOTS"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                    Text(String(format: "%.0f", proof.dotsScore))
                        .font(Theme.Typography.statNumeral)
                        .tracking(Theme.Typography.statNumeralTracking)
                        .foregroundStyle(proof.isCertified ? Theme.Colors.ember : Theme.Colors.textPrimary)
                }
            }

            // Video Player Card / Web Video Link / Embedded Preview
            if let video = proof.videoURL, !video.isEmpty {
                if let url = URL(string: video) {
                    Button {
                        presentedURL = IdentifiableURL(url)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .fill(Theme.Colors.surfaceSunken)
                                .frame(height: 180)

                            VStack(spacing: Theme.Spacing.sm) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.ember)
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "play.fill")
                                        .font(Theme.Typography.cardTitle)
                                        .foregroundStyle(Theme.Colors.textOnEmber)
                                        .offset(x: 2)
                                }

                                Text(L10n.t("点击播放试举视频 (支持慢放)", "Tap to Play Video (Slow-Mo)"))
                                    .font(Theme.Typography.label)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.card)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                    .buttonStyle(.forgeCardPress)
                }
            }

            // Lifter Notes
            if let notes = proof.notes, !notes.isEmpty {
                Text(notes)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(3)
            }

            Divider().background(Theme.Colors.borderHairline)

            // Bottom Social Action Bar: Like/Stoke + Comment + Witness Status
            HStack(spacing: 12) {
                // Like / Stoke Button
                Button {
                    liked.toggle()
                    likeCount += liked ? 1 : -1
                    ForgeHaptics.strike()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: liked ? "flame.fill" : "flame")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(liked ? Theme.Colors.ember : Theme.Colors.textMuted)

                        Text("\(likeCount)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(liked ? Theme.Colors.ember : Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(liked ? Theme.Colors.ember.opacity(0.12) : Theme.Colors.surfaceSunken, in: Capsule())
                    .overlay(Capsule().strokeBorder(liked ? Theme.Colors.ember.opacity(0.4) : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline))
                }
                .buttonStyle(.forgePress)

                // Comment Button
                Button {
                    showCommentsSheet = true
                    ForgeHaptics.selection()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textMuted)

                        Text(L10n.t("评论", "Comment"))
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.surfaceSunken, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline))
                }
                .buttonStyle(.forgePress)
                .sheet(isPresented: $showCommentsSheet) {
                    CommentsSheet(
                        targetID: proof.id,
                        title: "\(proof.userDisplayName ?? L10n.t("铁友", "Lifter")) · \(proof.exerciseDisplayName)",
                        viewerID: currentUserID,
                        viewerName: "我"
                    )
                }

                Spacer()

                // If not self, show Witness Button (验杠)
                if proof.userID != currentUserID && !proof.isCertified {
                    HStack(spacing: 8) {
                        Button {
                            hasWitnessed = true
                            onWitness(.confirm)
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "hammer.fill")
                                    .font(Theme.Typography.label)
                                Text(hasWitnessed ? L10n.t("已验杠", "Witnessed") : L10n.t("验杠", "Witness"))
                                    .font(Theme.Typography.cardTitle)
                            }
                            .foregroundStyle(Theme.Colors.textOnEmber)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        }
                        .buttonStyle(.forgePress)
                        .disabled(hasWitnessed)

                        Menu {
                            Button(role: .destructive) {
                                hasWitnessed = true
                                onWitness(.flag)
                            } label: {
                                Label(L10n.t("质疑标记 (需2人复核)", "Flag Attempt (Needs 2 to review)"), systemImage: "flag.fill")
                            }
                        } label: {
                            Image(systemName: "flag")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textMuted)
                                .padding(8)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(proof.isCertified ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: proof.isCertified ? Theme.Border.certified : Theme.Border.hairline)
        )
        .onAppear {
            liked = proof.likedByMe
            likeCount = max(proof.likeCount, 4)
        }
        .sheet(item: $presentedURL) { item in
            FeedVideoPlayerSheet(
                videoURL: item.url,
                title: "\(proof.exerciseDisplayName) \(formatKg(proof.weightKg))kg × \(proof.reps)",
                subtitle: "\(proof.userDisplayName ?? L10n.t("铁友", "Lifter")) · \(L10n.t("力量分", "DOTS")) \(String(format: "%.0f", proof.dotsScore))"
            )
        }
        .sheet(isPresented: $showReportSheet) {
            ReportProofSheet(
                reporterID: currentUserID,
                targetProofID: proof.id,
                targetUserID: proof.userID,
                targetUserName: proof.userDisplayName ?? "Lifter",
                onReportSubmitted: {
                    onBlockOrReport?()
                }
            )
        }
        .alert(L10n.t("确认拉黑该用户？", "Block this user?"), isPresented: $showBlockConfirmation) {
            Button(L10n.t("取消", "Cancel"), role: .cancel) {}
            Button(L10n.t("确认拉黑", "Block"), role: .destructive) {
                Task {
                    await blockService.blockUser(targetID: proof.userID, blockerID: currentUserID)
                    onBlockOrReport?()
                }
            }
        } message: {
            Text(L10n.t("拉黑后将不再向你展示该用户的动态，且对方无法与你进行同炉互动。", "Their content will be hidden and they will not be able to interact with you."))
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func timeAgoDisplay(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let diff = Int(now.timeIntervalSince(date))
        if diff < 60 {
            return L10n.t("刚刚", "Just now")
        } else if diff < 3600 {
            return L10n.t("\(diff / 60)分钟前", "\(diff / 60)m ago")
        } else if diff < 86400 {
            return L10n.t("\(diff / 3600)小时前", "\(diff / 3600)h ago")
        } else if calendar.isDateInYesterday(date) {
            return L10n.t("昨天", "Yesterday")
        } else {
            let days = diff / 86400
            return L10n.t("\(days)天前", "\(days)d ago")
        }
    }

    private func crewNameFor(_ name: String?) -> String {
        guard let name = name else { return L10n.t("玄铁重工", "Dark Iron Forge") }
        if name.contains("麦昆") {
            return L10n.t("闪电车队", "Lightning Squad")
        } else if name.contains("水手") {
            return L10n.t("大力菠菜营", "Popeye Camp")
        } else {
            return L10n.t("玄铁重工", "Dark Iron Forge")
        }
    }
}
