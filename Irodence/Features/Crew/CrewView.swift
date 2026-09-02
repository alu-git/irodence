import SwiftUI

/// Main Crew (熔炉) Screen: Phase 4.
/// Features heat meter (炉温), quenching (淬火), member strike rows (锤击),
/// rust states (生锈), and one-tap nudge (催一下).
struct CrewView: View {
    let userID: UUID

    @StateObject private var crewService = CrewService()
    @State private var nudgeSentUserID: UUID?
    @State private var isViewActive = false
    @State private var showCreateCrewSheet = false
    @State private var showInviteSheet = false
    @State private var showLeaveConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if crewService.isLoading && crewService.currentCrew == nil {
                        ForgeLoadingView(L10n.t("唤醒熔炉热度…", "Waking up forge heat…"))
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Spacing.xl * 2)
                    } else if let crew = crewService.currentCrew {
                        // 1. Crew Header Card
                        crewHeaderCard(crew)

                        // 2. Furnace Heat Meter (炉温 & 淬火)
                        heatMeterCard(crew)

                        // 3. Member Strikes & Rust Status
                        membersListCard(crew)
                    } else {
                        // Not in a crew -> Available crews / Create crew
                        noCrewView
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("熔炉", "Crew"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.t("铁证 · 熔炉", "Irodence · Crew"))
                        .font(Theme.Typography.screenTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if crewService.currentCrew != nil {
                        Menu {
                            Button {
                                showInviteSheet = true
                            } label: {
                                Label(L10n.t("邀请铁友入炉", "Invite Members"), systemImage: "person.badge.plus")
                            }

                            Button(role: .destructive) {
                                showLeaveConfirm = true
                            } label: {
                                Label(L10n.t("退出熔炉", "Leave Crew"), systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                    } else {
                        Button {
                            showCreateCrewSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text(L10n.t("创建", "Create"))
                            }
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.ember)
                        }
                    }
                }
            }
            .alert(L10n.t("确认退出熔炉？", "Leave Crew?"), isPresented: $showLeaveConfirm) {
                Button(L10n.t("取消", "Cancel"), role: .cancel) { }
                Button(L10n.t("退出", "Leave"), role: .destructive) {
                    if let crew = crewService.currentCrew {
                        Task {
                            try? await crewService.leaveCrew(crewID: crew.id, userID: userID)
                        }
                    }
                }
            } message: {
                Text(L10n.t("退出后本周已贡献的炉温将保留在熔炉中。", "Your heat contribution this week will remain in the crew."))
            }
            .sheet(isPresented: $showCreateCrewSheet) {
                CreateCrewSheet(userID: userID, crewService: crewService)
            }
            .sheet(isPresented: $showInviteSheet) {
                CrewInviteSheet(crew: crewService.currentCrew, userID: userID) {
                    Task { await crewService.loadUserCrew(userID: userID) }
                }
            }
            .onAppear { isViewActive = true }
            .onDisappear { isViewActive = false }
            .task {
                await crewService.loadUserCrew(userID: userID)
            }
            .refreshable {
                await crewService.loadUserCrew(userID: userID)
            }
        }
    }

    // MARK: - Subviews

    private func crewHeaderCard(_ crew: Crew) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                    Text(crew.localizedName)
                        .font(Theme.Typography.screenTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(crew.localizedDescription ?? L10n.t("百炼成钢，同炉淬火", "Tempered together, forged as one"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Spacer()

                // Member count & active badge
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(Theme.Typography.label)
                        .foregroundStyle(crew.isActive ? Theme.Colors.ember : Theme.Colors.textMuted)
                    Text(crew.isActive ? L10n.t("已点火 (\(crew.memberCount)人)", "Ignited (\(crew.memberCount))") : L10n.t("蓄热中 (\(crew.memberCount)/4人)", "Heating (\(crew.memberCount)/4)"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(crew.isActive ? Theme.Colors.ember : Theme.Colors.textMuted)
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs / 2)
                .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
            }

            Divider().background(Theme.Colors.borderHairline)

            HStack {
                Text(L10n.t("共同训练添柴 · 提升周炉温", "Train together to boost furnace heat"))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                Button {
                    showInviteSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.t("邀请铁友", "Invite"))
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.Colors.ember, in: Capsule())
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
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    private func heatMeterCard(_ crew: Crew) -> some View {
        let totalHeat = crewService.currentHeat?.totalHeat ?? 0
        let targetHeat = crewService.currentHeat?.targetHeat ?? crew.weeklyHeatTarget
        let progress = min(Double(totalHeat) / Double(max(targetHeat, 1)), 1.0)
        let isQuenched = crewService.currentHeat?.isQuenched ?? (totalHeat >= targetHeat)

        return ZStack(alignment: .bottom) {
            // Ambient looping rising embers behind the 炉温 numeral
            FurnaceHeatMeterView(heatPercentage: progress, isPaused: !isViewActive)
                .frame(height: 120)
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                        Text(L10n.t("本周炉温", "Weekly Heat"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(L10n.t("全员训练添柴，达成目标即可淬火", "Log workouts to build heat and quench the forge"))
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    Spacer()

                    // Quenched status stamp
                    Text(isQuenched ? L10n.t("已淬火", "Quenched") : L10n.t("蓄热中", "Heating"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(isQuenched ? Theme.Colors.emberDeep : Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs / 2)
                        .background(
                            isQuenched ? Theme.Colors.ember : Theme.Colors.surfaceSunken,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.stamp)
                        )
                }

                // Heat Progress Bar
                ProgressView(value: progress)
                    .tint(Theme.Colors.ember)
                    .background(Theme.Colors.surfaceSunken)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.stamp))

                HStack {
                    Text(L10n.t("\(totalHeat) / \(targetHeat) 炉温", "\(totalHeat) / \(targetHeat) Heat"))
                        .font(Theme.Typography.statNumeral)
                        .tracking(Theme.Typography.statNumeralTracking)
                        .foregroundStyle(isQuenched ? Theme.Colors.ember : Theme.Colors.textPrimary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Colors.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(isQuenched ? Theme.Colors.ember : Theme.Colors.borderMetal, lineWidth: isQuenched ? Theme.Border.certified : Theme.Border.hairline)
        )
    }

    private func membersListCard(_ crew: Crew) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text(L10n.t("熔炉铁匠 (\(crewService.members.count))", "Crew Members (\(crewService.members.count))"))
                    .font(Theme.Typography.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(L10n.t("本周锤击 (次训练)", "Strikes (Workouts)"))
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            Divider()
                .background(Theme.Colors.borderHairline)

            ForEach(crewService.members) { member in
                memberRow(member, crewID: crew.id)
                if member.id != crewService.members.last?.id {
                    Divider()
                        .background(Theme.Colors.borderHairline)
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
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }

    private func memberRow(_ member: CrewMember, crewID: UUID) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.surfaceSunken)
                Image(systemName: "person.fill")
                    .font(Theme.Typography.label)
                    .foregroundStyle(member.isRusted ? Theme.Colors.rust : Theme.Colors.textMuted)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(member.localizedDisplayName)
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(member.isRusted ? Theme.Colors.rust : Theme.Colors.textPrimary)
                    if member.role == "captain" || member.role == "leader" {
                        Text(L10n.t("炉长", "Captain"))
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.ember)
                    }
                }

                if member.isRusted {
                    Text(L10n.t("已生锈 · 7天未训练", "Rusted · 7d inactive"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.rust)
                        .transition(Effects.rustClears)
                } else {
                    Text(L10n.t("火热运转中", "Active & Burning"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            Spacer()

            if member.isRusted && member.userID != userID {
                Button {
                    ForgeHaptics.nudge()
                    Task {
                        try? await crewService.sendNudge(
                            crewID: crewID,
                            senderID: userID,
                            targetID: member.userID
                        )
                        nudgeSentUserID = member.userID
                    }
                } label: {
                    Text(nudgeSentUserID == member.userID ? L10n.t("已加炭", "Nudged") : L10n.t("加炭", "Nudge"))
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.emberDeep)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs / 2)
                        .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.forgePress)
                .disabled(nudgeSentUserID == member.userID)
            } else {
                Text("\(member.strikesCount)")
                    .font(Theme.Typography.statNumeral)
                    .tracking(Theme.Typography.statNumeralTracking)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
    }

    private var noCrewView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "flame")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Theme.Colors.ember)
                Text(L10n.t("暂未加入熔炉", "Not in a Crew"))
                    .font(Theme.Typography.screenTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(L10n.t("加入 4–20 人的专属熔炉，共同贡献每周炉温，击退锈迹", "Join a 4–20 member crew, build weekly furnace heat, and beat the rust"))
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, Theme.Spacing.lg)

            VStack(spacing: Theme.Spacing.md) {
                Button {
                    showCreateCrewSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(L10n.t("创建我的熔炉", "Create My Crew"))
                            .font(Theme.Typography.cardTitle)
                    }
                    .foregroundStyle(Theme.Colors.emberDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                }
                .buttonStyle(.forgePress)

                if !crewService.availableCrews.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(L10n.t("发现熔炉", "Discover Crews"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        ForEach(crewService.availableCrews) { crew in
                            HStack {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                                    Text(crew.name)
                                        .font(Theme.Typography.cardTitle)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text(L10n.t("\(crew.memberCount)/20 成员", "\(crew.memberCount)/20 members"))
                                        .font(Theme.Typography.label)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                                Spacer()
                                Button(L10n.t("加入", "Join")) {
                                    Task {
                                        try? await crewService.joinCrew(crewID: crew.id, userID: userID)
                                    }
                                }
                                .font(Theme.Typography.label)
                                .foregroundStyle(Theme.Colors.emberDeep)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                                .buttonStyle(.forgePress)
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
                    }
                }
            }
        }
    }
}

// MARK: - Create Crew Sheet

struct CreateCrewSheet: View {
    let userID: UUID
    @ObservedObject var crewService: CrewService

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var targetHeat = "500"
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.t("熔炉信息", "Crew Info"))) {
                    TextField(L10n.t("熔炉名称（例如：玄铁重工）", "Crew Name (e.g. Iron Works)"), text: $name)
                    TextField(L10n.t("熔炉誓言 / 简介（可选）", "Crew Motto / Bio (Optional)"), text: $description)
                }

                Section(header: Text(L10n.t("每周炉温目标", "Weekly Heat Target"))) {
                    Picker(L10n.t("目标炉温", "Target Heat"), selection: $targetHeat) {
                        Text(L10n.t("300 炉温 · 新人起步", "300 Heat · Beginner")).tag("300")
                        Text(L10n.t("500 炉温 · 标准强度", "500 Heat · Standard")).tag("500")
                        Text(L10n.t("1000 炉温 · 铁人熔炉", "1000 Heat · Heavy Forgers")).tag("1000")
                        Text(L10n.t("2000 炉温 · 百炼殿堂", "2000 Heat · Elite Masters")).tag("2000")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(L10n.t("创建熔炉", "Create Crew"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) { dismiss() }
                        .disabled(isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        create()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text(L10n.t("创建", "Create")).bold()
                        }
                    }
                    .disabled(isCreating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        let target = Int(targetHeat) ?? 500
        Task {
            do {
                try await crewService.createCrew(
                    name: trimmedName,
                    description: description.isEmpty ? nil : description,
                    weeklyHeatTarget: target,
                    userID: userID
                )
                isCreating = false
                dismiss()
            } catch {
                isCreating = false
                errorMessage = L10n.t("创建失败，请稍后重试", "Failed to create, please try again")
            }
        }
    }
}
