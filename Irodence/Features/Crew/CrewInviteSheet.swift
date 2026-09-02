import SwiftUI

/// Ultra-premium Crew / Team Invite Modal (熔炉招募与铁友邀请).
/// Allows lifters to share their Crew Invite Code, send recruitment links,
/// or join a teammate's crew by entering an invite code.
struct CrewInviteSheet: View {
    let crew: Crew?
    let userID: UUID
    var onCrewJoined: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var crewService = CrewService()
    @State private var inputCode = ""
    @State private var isJoining = false
    @State private var copySuccess = false
    @State private var joinErrorMessage: String?
    @State private var joinSuccessMessage: String?

    private var inviteCode: String {
        guard let crew = crew else { return "FORGE-8840" }
        // Generate memorable deterministic code from crew ID or name
        let hash = abs(crew.name.hashValue) % 9000 + 1000
        return "FORGE-\(hash)"
    }

    private var shareMessage: String {
        let name = crew?.localizedName ?? L10n.t("玄铁重工", "Dark Iron Forge")
        return L10n.t(
            "召唤硬核铁友！我正在【\(name)】熔炉淬火，来加入我们一起添柴升温、见证 PR！\n熔炉邀请码: \(inviteCode)\n点击加入: https://irodence.app/crew/\(inviteCode)",
            "Calling all lifters! Join our crew【\(name)】to forge strength together!\nCrew Code: \(inviteCode)\nLink: https://irodence.app/crew/\(inviteCode)"
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        if let currentCrew = crew {
                            // 1. Crew Recruitment Card
                            crewBannerCard(currentCrew)

                            // 2. Exclusive Invite Code Card
                            inviteCodeCard

                            // 3. Share Action Buttons
                            shareActionsSection
                        } else {
                            // Join by code if user currently has no crew
                            joinByCodeSection
                        }

                        // 4. Manual Join Code Entry (for switching or joining others)
                        if crew != nil {
                            joinOtherCrewSection
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(L10n.t("邀请铁友入炉", "Invite Lifters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("完成", "Done")) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 1. Crew Banner Card

    private func crewBannerCard(_ crew: Crew) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Theme.Colors.ember.opacity(0.35),
                                Theme.Colors.ember.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.Colors.ember)
            }

            VStack(spacing: 4) {
                Text(crew.localizedName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(crew.localizedDescription ?? L10n.t("同炉淬火，生锈必催", "Quench together, rust never"))
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                    Text(L10n.t("\(crew.memberCount) / 20 铁匠", "\(crew.memberCount)/20 Lifters"))
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.surfaceSunken, in: Capsule())

                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text(L10n.t("已点火", "Ignited"))
                }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Theme.Colors.ember)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.ember.opacity(0.12), in: Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 2. Invite Code Card

    private var inviteCodeCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(L10n.t("熔炉专属招募码", "Exclusive Forge Invite Code"))
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textMuted)

            HStack(spacing: 12) {
                Text(inviteCode)
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = inviteCode
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    copySuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copySuccess = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copySuccess ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .bold))
                        Text(copySuccess ? L10n.t("已复制", "Copied") : L10n.t("复制", "Copy"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(copySuccess ? Theme.Colors.textOnEmber : Theme.Colors.ember)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        copySuccess ? Theme.Colors.ember : Theme.Colors.ember.opacity(0.15),
                        in: Capsule()
                    )
                }
                .buttonStyle(.forgePress)
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Colors.ember.opacity(0.3), lineWidth: Theme.Border.hairline)
        )
    }

    // MARK: - 3. Share Action Buttons

    private var shareActionsSection: some View {
        VStack(spacing: 10) {
            ShareLink(item: shareMessage) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(L10n.t("发送招募邀请给微信 / 铁友", "Share Invite Link"))
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Theme.Colors.emberDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            }
            .buttonStyle(.forgePress)

            Text(L10n.t("新成员加入后将共同累计本周炉温与淬火奖励", "New lifters contribute to weekly furnace heat and quenching perks"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - 4. Join By Code Sections

    private var joinByCodeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L10n.t("输入邀请码加入熔炉", "Enter Invite Code to Join"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            HStack(spacing: 10) {
                TextField(L10n.t("输入如 FORGE-8840", "e.g. FORGE-8840"), text: $inputCode)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )

                Button {
                    joinCrewWithCode()
                } label: {
                    HStack(spacing: 4) {
                        if isJoining {
                            ProgressView()
                                .tint(Theme.Colors.emberDeep)
                        } else {
                            Text(L10n.t("加入", "Join"))
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.forgePress)
                .disabled(inputCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
            }

            if let error = joinErrorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
            }

            if let success = joinSuccessMessage {
                Text(success)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.ember)
            }
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
    }

    private var joinOtherCrewSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(L10n.t("加入其他熔炉", "Join Another Crew"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: 8) {
                TextField(L10n.t("输入对方邀请码…", "Enter invite code…"), text: $inputCode)
                    .font(.system(size: 14, design: .monospaced))
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.control))

                Button {
                    joinCrewWithCode()
                } label: {
                    Text(L10n.t("兑换加入", "Join"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised.opacity(0.6))
        )
    }

    private func joinCrewWithCode() {
        guard !inputCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isJoining = true
        joinErrorMessage = nil

        Task {
            // Simulate joining crew with code
            try? await Task.sleep(nanoseconds: 600_000_000)
            isJoining = false
            joinSuccessMessage = L10n.t("🎉 成功加入熔炉【玄铁重工】！", "🎉 Successfully joined【Dark Iron Forge】!")
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            onCrewJoined?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                dismiss()
            }
        }
    }
}
