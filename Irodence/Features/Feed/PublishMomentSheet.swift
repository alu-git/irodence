import SwiftUI
import PhotosUI
import UIKit

/// Quick modal to publish casual gym moments / pump checks.
struct PublishMomentSheet: View {
    let userID: UUID
    let userDisplayName: String
    let userCrewName: String?
    var initialDurationText: String? = nil
    var initialVolumeText: String? = nil
    var onPublished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var momentService = GymMomentService()

    @State private var caption = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedTags: Set<String> = ["#练后泵感"]
    @State private var isPublishing = false

    private let availableTags = [
        "#练后泵感", "#推力日", "#拉力日", "#蹲腿日",
        "#铁馆日常", "#状态拉满", "#硬核营养", "#玄铁重工"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // 1. Photo Picker / Preview
                        photoSection

                        // 2. Caption Text Editor
                        captionSection

                        // 3. Quick Tag Chips
                        tagsSection

                        // 4. Attached Workout Data (if any)
                        if initialDurationText != nil || initialVolumeText != nil {
                            attachedWorkoutCard
                        }
                    }
                    .padding(Theme.Spacing.md)
                }
            }
            .navigationTitle(L10n.t("晒今日泵感 / 日常", "Post Gym Moment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        publish()
                    } label: {
                        if isPublishing {
                            ProgressView()
                                .tint(Theme.Colors.ember)
                        } else {
                            Text(L10n.t("发布", "Post"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Colors.ember)
                        }
                    }
                    .disabled(isPublishing || (caption.isEmpty && selectedImageData == nil))
                }
            }
        }
    }

    // MARK: - Subviews

    private var photoSection: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))

                        Button {
                            selectedImageData = nil
                            selectedPhotoItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .background(Color.black.opacity(0.6), in: Circle())
                                .padding(8)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.Colors.ember)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("添加练后身材照 / 铁馆日常", "Add Pump Photo / Moment"))
                                .font(Theme.Typography.cardTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(L10n.t("支持自拍、器械、氮泵或合照", "Selfie, weights, or gym vibe"))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        Spacer()
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                    }
                }
            }
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(L10n.t("随心记录今日泵感、训练感受或铁馆日常…", "Share your workout pump or daily gym vibe…"), text: $caption, axis: .vertical)
                .lineLimit(3...6)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(14)
                .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                )
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("选择标签", "Tags"))
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(availableTags, id: \.self) { tag in
                    let isSelected = selectedTags.contains(tag)
                    Button {
                        if isSelected {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    } label: {
                        Text(tag)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Theme.Colors.textOnEmber : Theme.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? Theme.Colors.ember : Theme.Colors.surfaceRaised,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Color.clear : Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var attachedWorkoutCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.Colors.ember)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("附带今日训练数据水印", "Watermark Attached"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                HStack(spacing: 8) {
                    if let dur = initialDurationText {
                        Text("⏱ \(dur)")
                    }
                    if let vol = initialVolumeText {
                        Text("🏋️ \(vol)")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private func publish() {
        isPublishing = true
        momentService.publishMoment(
            userID: userID,
            userDisplayName: userDisplayName,
            userCrewName: userCrewName,
            imageData: selectedImageData,
            caption: caption.isEmpty ? nil : caption,
            workoutDurationText: initialDurationText,
            workoutVolumeText: initialVolumeText,
            tags: Array(selectedTags)
        )
        ForgeHaptics.strike()
        onPublished?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPublishing = false
            dismiss()
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
        return CGSize(width: width, height: currentY + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}
