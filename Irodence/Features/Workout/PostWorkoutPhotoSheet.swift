import SwiftUI
import PhotosUI

/// Sheet presented from WorkoutSummaryView after a workout is finished.
/// Lets the user pick a photo to attach to the workout post on the social feed.
struct PostWorkoutPhotoSheet: View {
    let workoutID: UUID
    let userID: UUID

    @StateObject private var photoService = WorkoutPhotoService()
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.zh.rawValue
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var uploadedURL: URL?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Preview or placeholder
                Group {
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 280, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                            .overlay(alignment: .bottomTrailing) {
                                PhotosPicker(selection: $pickerItem, matching: .images) {
                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .padding(10)
                                        .background(Color.black.opacity(0.5), in: Circle())
                                        .padding(10)
                                }
                            }
                    } else {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            VStack(spacing: 14) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 52))
                                    .foregroundStyle(Color.accentColor)
                                Text(L10n.t("添加训练照片", "Add a workout photo"))
                                    .font(.headline)
                                Text(L10n.t("选择一张照片分享到你的动态", "Pick a photo to share on your feed"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 280, height: 280)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showSuccess {
                    Label(L10n.t("已分享到你的动态！", "Shared to your feed!"), systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }

                if let err = photoService.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    // Upload button
                    Button {
                        guard let img = selectedImage else { return }
                        Task {
                            let url = await photoService.upload(
                                image: img,
                                workoutID: workoutID,
                                userID: userID
                            )
                            if url != nil {
                                withAnimation(.spring(duration: 0.4)) {
                                    showSuccess = true
                                    uploadedURL = url
                                }
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if photoService.isUploading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text(L10n.t("上传中…", "Uploading…"))
                                }
                            } else {
                                Label(L10n.t("分享到动态", "Share to Feed"), systemImage: "square.and.arrow.up")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            selectedImage == nil || photoService.isUploading
                                ? Color(.tertiarySystemFill)
                                : Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(
                            selectedImage == nil || photoService.isUploading ? Color.secondary : .white
                        )
                    }
                    .disabled(selectedImage == nil || photoService.isUploading)

                    Button(L10n.t("跳过", "Skip")) { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("分享训练照片", "Share Workout Photo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) { dismiss() }
                }
            }
            .onChange(of: pickerItem) { newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    withAnimation { selectedImage = uiImage }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
