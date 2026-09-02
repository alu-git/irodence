import Foundation
import Supabase
import UIKit

// MARK: - Model

struct WorkoutPhoto: Identifiable, Decodable {
    let id: UUID
    let workoutID: UUID
    let userID: UUID
    let storagePath: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case workoutID = "workout_id"
        case userID = "user_id"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }
}

// MARK: - Service

@MainActor
final class WorkoutPhotoService: ObservableObject {
    @Published private(set) var isUploading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private let bucket = "workout-photos"

    private struct PhotoInsert: Encodable {
        let workout_id: UUID
        let user_id: UUID
        let storage_path: String
    }

    /// Compress, upload to `workout-photos` bucket, and insert a metadata row.
    /// Returns the signed URL of the uploaded photo on success.
    func upload(image: UIImage, workoutID: UUID, userID: UUID) async -> URL? {
        guard let data = ProgressPhotoService.jpegData(for: image) else {
            errorMessage = L10n.t("图片格式不支持", "Unsupported image format")
            return nil
        }

        isUploading = true
        defer { isUploading = false }

        let path = "\(userID.uuidString)/\(workoutID.uuidString)/\(UUID().uuidString).jpg"

        do {
            try await client.storage
                .from(bucket)
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))

            let _: WorkoutPhoto = try await client
                .from("workout_photos")
                .insert(PhotoInsert(
                    workout_id: workoutID,
                    user_id: userID,
                    storage_path: path
                ))
                .select()
                .single()
                .execute()
                .value

            // Return a signed URL so the caller can preview the upload
            let signed = try await client.storage
                .from(bucket)
                .createSignedURL(path: path, expiresIn: 86400)
            return signed
        } catch {
            errorMessage = L10n.t("上传失败，请检查网络", "Upload failed, check your connection")
            return nil
        }
    }

    /// Fetch all photos for a given workout (for display on feed detail).
    func fetchPhotos(workoutID: UUID) async -> [WorkoutPhoto] {
        (try? await client
            .from("workout_photos")
            .select()
            .eq("workout_id", value: workoutID)
            .order("created_at", ascending: true)
            .execute()
            .value) ?? []
    }
}
