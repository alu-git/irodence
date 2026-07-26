import PhotosUI
import SwiftUI

/// "进步照片" section for the Profile tab: photo picker + thumbnail grid +
/// fullscreen viewer. Images live in private storage; thumbnails load via
/// signed URLs from ProgressPhotoService.
struct ProgressPhotosSection: View {
    @StateObject private var service = ProgressPhotoService()
    @State private var pickerItem: PhotosPickerItem?
    @State private var selected: ProgressPhoto?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        Section("进步照片") {
            if service.photos.isEmpty && !service.isLoading {
                Text("记录体型变化，和力量数据一起见证进步")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !service.photos.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(service.photos) { photo in
                        Button { selected = photo } label: {
                            PhotoCell(url: service.imageURLs[photo.id])
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                if service.isUploading {
                    HStack {
                        ProgressView()
                        Text("上传中…")
                    }
                } else {
                    Label("添加照片", systemImage: "camera.fill")
                }
            }
            .disabled(service.isUploading)

            if let error = service.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .task { await service.loadPhotos() }
        .onChange(of: pickerItem) { newItem in
            guard let newItem else { return }
            Task {
                defer { pickerItem = nil }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    service.errorMessage = "图片读取失败"
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
                    Color(.tertiarySystemFill)
                    ProgressView()
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                Color.black.ignoresSafeArea()
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        ProgressView()
                    }
                }
            }
            .navigationTitle(photo.takenAt.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}
