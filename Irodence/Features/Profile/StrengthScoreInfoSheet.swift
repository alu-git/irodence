import SwiftUI

// MARK: - Info Button

/// Small tappable "怎么算的" (How it's calculated) button to place next to 力量分 displays.
struct StrengthScoreInfoButton: View {
    @State private var showInfoSheet = false
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    var body: some View {
        Button {
            showInfoSheet = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                Text(L10n.t("怎么算的", "How it works"))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showInfoSheet) {
            StrengthScoreInfoSheet()
        }
    }
}

// MARK: - Info Sheet Modal

/// Concise modal explaining that 力量分 (Strength Score) normalizes 1RM based on sex & bodyweight
/// using the DOTS formula so lifters of all bodyweights can be fairly compared.
struct StrengthScoreInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 46, height: 46)
                        Image(systemName: "function")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("力量分是如何计算的？", "How is Strength Score Calculated?"))
                            .font(.headline)
                        Text(L10n.t("相对力量公平评估标准", "Fair relative strength comparison"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t(
                        "力量分根据你的性别、体重、身高与年龄对极限力量（1RM）进行综合无偏折算。",
                        "Strength Score normalizes your 1RM based on sex, bodyweight, height, and age."
                    ))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                    Text(L10n.t(
                        "· 体重与性别：基于国际 DOTS 模型消除体重等级差异。\n· 身高：补偿身高臂长带来的做功距离与力臂杠杆差异。\n· 年龄：采用 IPF/McCulloch 大师年龄补偿系数，保障各年龄段公平竞技。",
                        "· Sex & Weight: Removes weight-class bias via standard DOTS.\n· Height: Adjusts for lever-arm & range-of-motion work differences.\n· Age: Applies IPF/McCulloch age compensation for 40+ lifters."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Low-prominence credibility mention of the DOTS formula (Requirement 4)
                // Note: The underlying mathematical scoring formula uses DOTS (Dynamic Objective Total Scoring).
                VStack(alignment: .center, spacing: 4) {
                    Text(L10n.t(
                        "算法底层采用国际力量举通用的 DOTS (Dynamic Objective Total Scoring) 评估模型",
                        "Scoring methodology is based on the international DOTS (Dynamic Objective Total Scoring) formula"
                    ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 8)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("关于力量分", "About Strength Score"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
    }
}
