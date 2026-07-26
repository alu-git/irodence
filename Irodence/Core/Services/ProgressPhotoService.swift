import Foundation
import Supabase
import UIKit

/// Progress photos: metadata in `progress_photos`, images in the private
/// `progress-photos` storage bucket (one folder per user).
///
/// Fully disk-cached: photo rows and downloaded image bytes live in the
/// Caches directory, so the gallery renders instantly offline. Remote is
/// refreshed silently in the background; a photo's bytes are downloaded
/// once and served from disk afterwards.
@MainActor
final class ProgressPhotoService: ObservableObject {
    @Published private(set) var photos: [ProgressPhoto] = []
    /// Display URLs keyed by photo id — local file URLs once downloaded,
    /// signed remote URLs only for bytes not cached yet.
    @Published private(set) var imageURLs: [UUID: URL] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isUploading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private let bucket = "progress-photos"
    private let signedURLTTL = 3600 // seconds

    private var userID: UUID? {
        client.auth.currentUser?.id
    }

    private var metadataCacheKey: String {
        "progress_photos_\(userID?.uuidString ?? "anon")"
    }

    nonisolated private static var imageDirectory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("progress_photo_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated private static func imageFile(for photoID: UUID) -> URL {
        imageDirectory.appendingPathComponent("\(photoID.uuidString).jpg")
    }

    // MARK: - Load

    func loadPhotos() async {
        guard let userID else { return }

        // 1. Instant render from disk: cached rows + already-downloaded images.
        if photos.isEmpty,
           let cached: [ProgressPhoto] = DiskCache.load([ProgressPhoto].self, key: metadataCacheKey) {
            photos = cached
        }
        for photo in photos where imageURLs[photo.id] == nil {
            let file = Self.imageFile(for: photo.id)
            if FileManager.default.fileExists(atPath: file.path) {
                imageURLs[photo.id] = file
            }
        }

        // 2. Silent background refresh of the metadata rows.
        isLoading = photos.isEmpty
        defer { isLoading = false }
        do {
            photos = try await client
                .from("progress_photos")
                .select()
                .eq("user_id", value: userID)
                .order("taken_at", ascending: false)
                .execute()
                .value
            DiskCache.save(photos, key: metadataCacheKey)
        } catch {
            if photos.isEmpty {
                errorMessage = "照片加载失败"
            }
            return
        }

        // 3. Download any images not on disk yet (parallel), then swap each
        //    entry to its local file as it lands.
        let missing = photos.filter {
            imageURLs[$0.id] == nil || imageURLs[$0.id]?.isFileURL == false
        }
        guard !missing.isEmpty else { return }

        await withTaskGroup(of: (UUID, URL?).self) { group in
            for photo in missing {
                group.addTask { [client, bucket, signedURLTTL] in
                    guard let signed = try? await client.storage
                        .from(bucket)
                        .createSignedURL(path: photo.storagePath, expiresIn: signedURLTTL),
                        let (data, _) = try? await URLSession.shared.data(from: signed)
                    else { return (photo.id, nil) }
                    let file = Self.imageFile(for: photo.id)
                    try? data.write(to: file, options: .atomic)
                    return (photo.id, file)
                }
            }
            for await (id, file) in group {
                if let file { imageURLs[id] = file }
            }
        }
    }

    // MARK: - Upload

    struct PhotoInsert: Encodable {
        let user_id: UUID
        let storage_path: String
    }

    /// Compresses (max side 1600pt, JPEG 0.8), uploads to storage, inserts
    /// the metadata row, and writes the bytes to disk — the new photo shows
    /// immediately without a re-download.
    func upload(_ image: UIImage) async -> Bool {
        guard let userID else { return false }
        guard let data = Self.jpegData(for: image) else {
            errorMessage = "图片格式不支持"
            return false
        }
        isUploading = true
        defer { isUploading = false }

        let path = "\(userID.uuidString)/\(UUID().uuidString).jpg"
        do {
            try await client.storage
                .from(bucket)
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
            let photo: ProgressPhoto = try await client
                .from("progress_photos")
                .insert(PhotoInsert(user_id: userID, storage_path: path))
                .select()
                .single()
                .execute()
                .value

            let file = Self.imageFile(for: photo.id)
            try? data.write(to: file, options: .atomic)
            photos.insert(photo, at: 0)
            imageURLs[photo.id] = file
            DiskCache.save(photos, key: metadataCacheKey)
            return true
        } catch {
            errorMessage = "上传失败，请检查网络"
            return false
        }
    }

    // MARK: - Delete

    /// Removes the metadata row, the storage object, and the local copy.
    func delete(_ photo: ProgressPhoto) async {
        do {
            try await client
                .from("progress_photos")
                .delete()
                .eq("id", value: photo.id)
                .execute()
            try? await client.storage.from(bucket).remove(paths: [photo.storagePath])
            photos.removeAll { $0.id == photo.id }
            imageURLs.removeValue(forKey: photo.id)
            try? FileManager.default.removeItem(at: Self.imageFile(for: photo.id))
            DiskCache.save(photos, key: metadataCacheKey)
        } catch {
            errorMessage = "删除失败"
        }
    }

    // MARK: - Helpers

    /// Downscales so uploads stay small, then JPEG-encodes.
    static func jpegData(for image: UIImage,
                         maxSide: CGFloat = 1600,
                         quality: CGFloat = 0.8) -> Data? {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
