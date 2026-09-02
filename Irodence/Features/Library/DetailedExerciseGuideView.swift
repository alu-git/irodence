import SwiftUI

/// Full-screen detailed exercise guide & tutorial view with anatomical muscle diagrams,
/// step-by-step form cues, common mistakes to avoid, and open-source visual/video tutorials.
struct DetailedExerciseGuideView: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @State private var presentedURL: IdentifiableURL? = nil

    private var activation: ExerciseMuscles {
        ExerciseMuscleMap.muscles(for: exercise)
    }

    /// Open-source visual guide URL using jsDelivr CDN mirror — accessible globally including Mainland China.
    private var visualTutorialURL: URL? {
        let nameSlug = exercise.nameEn
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return URL(string: "https://cdn.jsdelivr.net/gh/yuhang-ch/exercise-gifs@main/gifs/\(nameSlug).gif")
    }

    private var bilibiliSearchURL: URL {
        let query = "\(exercise.nameZh) 动作要领 教程"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://search.bilibili.com/all?keyword=\(query)")!
    }

    private var youtubeSearchURL: URL {
        let query = "\(exercise.nameEn) exercise form tutorial"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.youtube.com/results?search_query=\(query)")!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header Badges
                HStack(spacing: 10) {
                    Label(exercise.primaryMuscle.displayName, systemImage: "figure.arms.open")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())

                    Label(exercise.equipment.displayName, systemImage: "dumbbell.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemFill), in: Capsule())

                    Label(exercise.isCompound ? L10n.t("复合动作", "Compound") : L10n.t("孤立动作", "Isolation"), systemImage: "bolt.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }

                // MARK: - Anatomical Muscle Diagram Card
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("解剖与目标肌群", "Anatomy & Targeted Muscles"))
                        .font(.headline)

                    MuscleDiagramPairView(
                        activated: activation.primary,
                        secondaryActivated: activation.secondary
                    )
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 16) {
                        Label(L10n.t("主要受力肌群", "Primary Target"), systemImage: "circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Label(L10n.t("协同辅助肌群", "Secondary Synergist"), systemImage: "circle.fill")
                            .foregroundStyle(Color.accentColor.opacity(0.45))
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // MARK: - Open-Source Visual & Video Tutorial Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "play.tv.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(L10n.t("图解与动作演示", "Visual & Demonstration Tutorial"))
                            .font(.headline)
                    }

                    if let visualTutorialURL {
                        AsyncImage(url: visualTutorialURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                visualFallbackCard
                            case .empty:
                                HStack {
                                    Spacer()
                                    ProgressView(L10n.t("加载开源动作演示中…", "Loading visual tutorial…"))
                                    Spacer()
                                }
                                .padding(.vertical, 24)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        visualFallbackCard
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // MARK: - Detailed Step-by-Step Instructions
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.t("标准动作要领与指南", "Step-by-Step Execution Guide"))
                        .font(.headline)

                    if let instructions = exercise.instructions, !instructions.isEmpty {
                        Text(instructions)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(4)
                    }

                    Divider()

                    guideStep(
                        number: "1",
                        title: L10n.t("预备姿势与调整", "1. Setup & Starting Stance"),
                        detail: L10n.t(
                            "调整器械高度或握距，核心收紧，保持脊柱中立与稳定基底。",
                            "Adjust equipment height or grip width. Brace core tightly and maintain neutral spine."
                        )
                    )

                    guideStep(
                        number: "2",
                        title: L10n.t("向心发力阶段", "2. Concentric / Peak Drive Phase"),
                        detail: L10n.t(
                            "呼气发力，由目标肌群主导平稳拉起或推起重量，在顶峰稍作停顿感受收缩。",
                            "Exhale and drive weight smoothly with primary target muscles. Pause briefly at peak contraction."
                        )
                    )

                    guideStep(
                        number: "3",
                        title: L10n.t("离心控制阶段", "3. Eccentric / Controlled Lowering"),
                        detail: L10n.t(
                            "吸气并富有控制地离心还原，保持目标肌肉张力，避免惯性卸力。",
                            "Inhale and lower weight with steady control (2-3 sec), maintaining muscle tension."
                        )
                    )

                    guideStep(
                        number: "4",
                        title: L10n.t("常见错误与注意项", "4. Common Mistakes & Form Cues"),
                        detail: L10n.t(
                            "切忌借力耸肩或腰部过度借力；保持关节顺应运动轨迹，勿锁定关节。",
                            "Avoid arching or using momentum. Move along natural joint planes without hard locking joints."
                        )
                    )
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // MARK: - Realistic Strength Standards Ladder
                ExerciseStrengthStandardsView(exercise: exercise)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(exercise.primaryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.t("关闭", "Close")) { dismiss() }
            }
        }
        .sheet(item: $presentedURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private var visualFallbackCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)

            Text(L10n.t("在线视频动作教学与演示", "Online Video Demonstrations"))
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                Button {
                    presentedURL = IdentifiableURL(bilibiliSearchURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                        Text(L10n.t("Bilibili 哔哩哔哩 ➔", "Watch on Bilibili ➔"))
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.pink, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    presentedURL = IdentifiableURL(youtubeSearchURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.tv.fill")
                        Text(L10n.t("YouTube ➔", "Watch on YouTube ➔"))
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.red, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func guideStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
