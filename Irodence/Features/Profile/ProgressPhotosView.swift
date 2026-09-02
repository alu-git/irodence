import PhotosUI
import SwiftUI

/// "进步照片" component: photo picker + thumbnail grid + fullscreen viewer.
/// Images live in private storage; thumbnails load via signed URLs from ProgressPhotoService.
/// Styled according to IRODENCE_PALETTE.md and IRODENCE_DESIGN.md.
struct ProgressPhotosSection: View {
    @StateObject private var service = ProgressPhotoService()
    @State private var pickerItem: PhotosPickerItem?
    @State private var selected: ProgressPhoto?

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("体型对比", "Progress Photos"))
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(L10n.t("与力量数据同步见证蜕变", "Visual transformation logs"))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                Spacer()

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    HStack(spacing: 4) {
                        if service.isUploading {
                            ProgressView()
                                .tint(Theme.Colors.ember)
                                .scaleEffect(0.8)
                            Text(L10n.t("上传中…", "Uploading…"))
                                .font(Theme.Typography.label)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(Theme.Typography.label)
                            Text(L10n.t("添加照片", "Add Photo"))
                                .font(Theme.Typography.label)
                        }
                    }
                    .foregroundStyle(Theme.Colors.ember)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs / 2)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                    )
                }
                .buttonStyle(.plain)
                .disabled(service.isUploading)
            }

            // Empty State or Photo Grid
            if service.photos.isEmpty && !service.isLoading {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.top, Theme.Spacing.xs)

                    Text(L10n.t("暂无体型照片", "No Progress Photos Yet"))
                        .font(Theme.Typography.cardTitle)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text(L10n.t("定期拍摄身材对比照片，与力量突破一同见证肉体蜕变。照片仅私密保存。", "Track your visual transformation alongside your strength PRs. Photos are stored securely and private to you."))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.sm)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "plus")
                            Text(L10n.t("上传第一张身材照", "Add First Photo"))
                        }
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(Theme.Colors.surfaceSunken)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.Spacing.xs / 2)
                    .padding(.bottom, Theme.Spacing.xs)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.Colors.surfaceSunken.opacity(0.5))
                )
            } else if !service.photos.isEmpty {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(service.photos) { photo in
                        Button { selected = photo } label: {
                            PhotoCell(url: service.imageURLs[photo.id])
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let error = service.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.danger)
            }
        }
        .task { await service.loadPhotos() }
        .onChange(of: pickerItem) { newItem in
            guard let newItem else { return }
            Task {
                defer { pickerItem = nil }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    service.errorMessage = L10n.t("图片读取失败", "Failed to load image")
                    return
                }
                _ = await service.upload(image)
            }
        }
        .sheet(item: $selected) { photo in
            ProgressPhotoDetailView(
                photo: photo,
                url: service.imageURLs[photo.id]
            ) {
                Task { await service.delete(photo) }
            }
        }
    }
}

/// One grid thumbnail.
private struct PhotoCell: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    Theme.Colors.surfaceSunken
                    ProgressView().tint(Theme.Colors.ember)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .strokeBorder(Theme.Colors.borderMetal, lineWidth: Theme.Border.hairline)
        )
    }
}

/// Fullscreen photo with date and delete.
struct ProgressPhotoDetailView: View {
    let photo: ProgressPhoto
    let url: URL?
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.surfaceSunken.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        ProgressView().tint(Theme.Colors.ember)
                    }
                }
            }
            .navigationTitle(photo.takenAt.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
        }
    }
}
