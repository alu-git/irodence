import SwiftUI
import PhotosUI
import AVKit

/// Modal sheet for submitting a PR proof to the feed (上铁证).
/// Enforces IRODENCE_SAFETY.md privacy defaults (crew-only default, minor checks).
struct SubmitProofSheet: View {
    let userID: UUID
    let exercise: Exercise
    let weightKg: Double
    let reps: Int
    let estimated1RM: Double
    let previousBest1RM: Double?
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var videoURL = ""
    @State private var visibility: ProofVisibility = .crewOnly // Default crew only per Section 2
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @StateObject private var proofService = ProofService()

    // Video Picker States
    enum VideoSourceType: String, CaseIterable {
        case album = "从相册选取"
        case urlLink = "视频链接"

        var displayName: String {
            switch self {
            case .album: return L10n.t("从相册选取", "Camera Roll")
            case .urlLink: return L10n.t("视频链接", "Web Link")
            }
        }
    }

    @State private var videoSource: VideoSourceType = .album
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var localVideoThumbnail: UIImage? = nil
    @State private var localVideoDurationSeconds: Int = 0
    @State private var isProcessingVideo = false

    private var calculatedDots: Double {
        DOTSCalculator.score(liftedKg: estimated1RM, bodyweightKg: 75.0, sex: .male)
    }

    private var estimatedTier: StrengthTier {
        if let lift = CoreLift.allCases.first(where: { $0.exerciseNameEn == exercise.nameEn }) {
            return StrengthStandards.tier(for: calculatedDots, lift: lift, sex: .male)
        }
        return .reforged
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // PR Celebration Header Card
                    VStack(spacing: Theme.Spacing.sm) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .font(Theme.Typography.sectionTitle)
                                .foregroundStyle(Theme.Colors.ember)
                            Text(L10n.t("新突破！准备上铁证", "New PR! Submit Proof"))
                                .font(Theme.Typography.sectionTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Label(estimatedTier.displayName, systemImage: estimatedTier.systemImage)
                                .font(Theme.Typography.label)
                                .foregroundStyle(Theme.Colors.textOnEmber)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.xs / 2)
                                .background(Theme.Colors.ember, in: RoundedRectangle(cornerRadius: Theme.Radius.stamp))
                        }

                        Divider().background(Theme.Colors.borderHairline)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.primaryName)
                                    .font(Theme.Typography.cardTitle)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(L10n.t("\(formatKg(weightKg)) kg × \(reps) 次", "\(formatKg(weightKg)) kg × \(reps) reps"))
                                    .font(Theme.Typography.statNumeral)
                                    .tracking(Theme.Typography.statNumeralTracking)
                                    .foregroundStyle(Theme.Colors.ember)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(L10n.t("预估 1RM", "Est. 1RM"))
                                    .font(Theme.Typography.label)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                Text("\(formatKg(estimated1RM)) kg")
                                    .font(Theme.Typography.statNumeral)
                                    .foregroundStyle(Theme.Colors.textPrimary)
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
                            .strokeBorder(Theme.Colors.ember, lineWidth: Theme.Border.certified)
                    )

                    // Polished Video Proof Uploader Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text(L10n.t("试举视频 (验杠凭据)", "Video Proof (Optional)"))
                                .font(Theme.Typography.cardTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Spacer()

                            Picker("", selection: $videoSource) {
                                ForEach(VideoSourceType.allCases, id: \.self) { source in
                                    Text(source.displayName).tag(source)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 170)
                        }

                        if videoSource == .album {
                            if let thumb = localVideoThumbnail {
                                // Attached video card preview
                                HStack(spacing: Theme.Spacing.md) {
                                    ZStack {
                                        Image(uiImage: thumb)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(Theme.Colors.ember)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(L10n.t("视频已就绪", "Video Ready"))
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Theme.Colors.textPrimary)

                                        Text(L10n.t("时长: \(localVideoDurationSeconds) 秒 · 隐私数据已抹除", "Length: \(localVideoDurationSeconds)s · EXIF stripped"))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }

                                    Spacer()

                                    Button {
                                        localVideoThumbnail = nil
                                        selectedVideoItem = nil
                                        videoURL = ""
                                        ForgeHaptics.selection()
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.Colors.danger)
                                            .padding(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(Theme.Spacing.sm)
                                .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                                        .strokeBorder(Theme.Colors.ember, lineWidth: Theme.Border.hairline)
                                )
                            } else {
                                PhotosPicker(
                                    selection: $selectedVideoItem,
                                    matching: .videos,
                                    photoLibrary: .shared()
                                ) {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        if isProcessingVideo {
                                            ProgressView()
                                                .tint(Theme.Colors.ember)
                                        } else {
                                            Image(systemName: "video.badge.plus")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(Theme.Colors.ember)
                                        }

                                        Text(isProcessingVideo ? L10n.t("正在解析视频...", "Processing video...") : L10n.t("点击从相册选取试举视频", "Select Video from Camera Roll"))
                                            .font(Theme.Typography.body)
                                            .foregroundStyle(Theme.Colors.textPrimary)

                                        Spacer()
                                    }
                                    .padding(Theme.Spacing.md)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.Colors.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                                    )
                                }
                                .buttonStyle(.plain)
                                .onChange(of: selectedVideoItem) { newItem in
                                    guard let item = newItem else { return }
                                    processSelectedVideo(item)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(Theme.Colors.textMuted)
                                TextField(L10n.t("例如：B站 / 抖音 / 视频直链", "e.g. YouTube, TikTok, or direct video URL"), text: $videoURL)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .fill(Theme.Colors.surfaceSunken)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                        }

                        Text(L10n.t("附带视频可接受铁友「验杠」，更快获得认证。原始视频的 EXIF/拍摄地点已自动清除。", "Videos allow community verification. Video EXIF & GPS metadata are stripped automatically."))
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    // Visibility Scope Selector (Default: Crew Only per Section 2)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(L10n.t("可见范围", "Visibility Scope"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Picker(L10n.t("可见范围", "Visibility"), selection: $visibility) {
                            ForEach(ProofVisibility.allCases, id: \.self) { scope in
                                Text(scope.displayName).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 2)

                        Text(visibility == .crewOnly
                             ? L10n.t("保守默认：仅同炉铁友可见。公域不可检索。", "Conservative default: Only crew members can view.")
                             : L10n.t("全网公开可见，允许其他认证铁友进行验杠。", "Publicly visible to all certified lifters."))
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    // Notes / Thoughts Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(L10n.t("试举心得以供铁友复核", "Lifter Notes for Verification"))
                            .font(Theme.Typography.cardTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        TextField(L10n.t("记录锁死状态、停顿深度、发力感受等...", "Note lockout, pause depth, effort level..."), text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(Theme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .fill(Theme.Colors.surfaceSunken)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.Typography.label)
                            .foregroundStyle(Theme.Colors.danger)
                    }

                    // Submit Action Button
                    Button {
                        submit()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(Theme.Colors.textOnEmber)
                            } else {
                                Image(systemName: "hammer.fill")
                                Text(L10n.t("上铁证 · 接受验杠", "Submit Proof · Get Verified"))
                            }
                        }
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textOnEmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Colors.ember)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.surfaceBase.ignoresSafeArea())
            .navigationTitle(L10n.t("上铁证", "Submit Proof"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.t("取消", "Cancel")) { dismiss() }
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
    }

    private func processSelectedVideo(_ item: PhotosPickerItem) {
        isProcessingVideo = true
        Task {
            do {
                if let movie = try await item.loadTransferable(type: MovieTransferable.self) {
                    let asset = AVURLAsset(url: movie.url)
                    let gen = AVAssetImageGenerator(asset: asset)
                    gen.appliesPreferredTrackTransform = true
                    let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                    if let cgImage = try? gen.copyCGImage(at: time, actualTime: nil) {
                        self.localVideoThumbnail = UIImage(cgImage: cgImage)
                    }
                    let duration = try? await asset.load(.duration)
                    let seconds = duration.map { Int($0.seconds) } ?? 15
                    self.localVideoDurationSeconds = max(1, seconds)
                    self.videoURL = movie.url.absoluteString
                    ForgeHaptics.selection()
                }
            } catch {
                errorMessage = L10n.t("解析视频失败，请重试", "Failed to parse video, please try again")
            }
            isProcessingVideo = false
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await proofService.submitProof(
                    userID: userID,
                    exerciseID: exercise.id,
                    weightKg: weightKg,
                    reps: reps,
                    estimated1RM: estimated1RM,
                    dotsScore: calculatedDots,
                    tier: estimatedTier.dbValue,
                    videoURL: videoURL.isEmpty ? nil : videoURL,
                    notes: notes.isEmpty ? nil : notes,
                    visibility: visibility
                )
                isSubmitting = false
                ForgeHaptics.prBreak()
                onSubmitted()
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = L10n.t("提交失败，请稍后重试", "Failed to submit, please try again")
            }
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// Helper Transferable representation for picking video files with PhotosPicker
struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            try? FileManager.default.removeItem(at: temp)
            try FileManager.default.copyItem(at: received.file, to: temp)
            return Self(url: temp)
        }
    }
}
