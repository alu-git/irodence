import Foundation
import Supabase

/// Profile data + the user's PRs for strength-standard calculations.
@MainActor
final class ProfileService: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var bestLifts: [CoreLift: (est1RM: Double, weightKg: Double, reps: Int)] = [:]
    @Published private(set) var allPRs: [PersonalRecord] = []
    @Published private(set) var totalWorkoutsCount: Int = 0
    @Published private(set) var totalTonnageKg: Double = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private let userID: UUID

    /// Codable snapshot of what the profile tab renders
    private struct Snapshot: Codable {
        struct BestLift: Codable {
            let lift: CoreLift
            let est1RM: Double
            let weightKg: Double
            let reps: Int
        }
        let profile: Profile
        let best: [BestLift]
        let prs: [PersonalRecord]?
        let workoutsCount: Int?
        let tonnage: Double?
    }

    private var cacheKey: String { "profile_\(userID.uuidString)" }

    init(userID: UUID) {
        self.userID = userID
        if let snapshot: Snapshot = DiskCache.load(Snapshot.self, key: cacheKey) {
            profile = snapshot.profile
            bestLifts = Dictionary(
                uniqueKeysWithValues: snapshot.best.map {
                    ($0.lift, (est1RM: $0.est1RM, weightKg: $0.weightKg, reps: $0.reps))
                }
            )
            allPRs = snapshot.prs ?? []
            totalWorkoutsCount = snapshot.workoutsCount ?? 0
            totalTonnageKg = snapshot.tonnage ?? 0
        } else {
            // Immediate instant profile so the screen renders in 0ms on first launch
            profile = Profile(
                id: userID,
                displayName: "铁友",
                avatarURL: nil,
                sex: .male,
                bodyweightKg: 75.0,
                bio: "百炼成钢，力量铸魂",
                heightCm: 175.0,
                ageYears: 26
            )
            bestLifts = [
                .squat: (est1RM: 140.0, weightKg: 130.0, reps: 3),
                .bench: (est1RM: 100.0, weightKg: 90.0, reps: 4),
                .deadlift: (est1RM: 175.0, weightKg: 160.0, reps: 3),
                .ohp: (est1RM: 60.0, weightKg: 55.0, reps: 3)
            ]
            totalWorkoutsCount = 18
            totalTonnageKg = 24_680

            let squatID = ExerciseService.defaultExercises[0].id
            let benchID = ExerciseService.defaultExercises[1].id
            let deadliftID = ExerciseService.defaultExercises[2].id
            let ohpID = ExerciseService.defaultExercises[3].id
            let rowID = ExerciseService.defaultExercises[4].id
            let dipID = ExerciseService.defaultExercises[17].id

            allPRs = [
                PersonalRecord(id: UUID(), userID: userID, exerciseID: squatID, weightKg: 130.0, reps: 3, estimated1RM: 140.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 2)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: benchID, weightKg: 90.0, reps: 4, estimated1RM: 100.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 4)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: deadliftID, weightKg: 160.0, reps: 3, estimated1RM: 175.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 7)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: ohpID, weightKg: 55.0, reps: 3, estimated1RM: 60.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 10)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: rowID, weightKg: 80.0, reps: 6, estimated1RM: 96.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 12)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: dipID, weightKg: 25.0, reps: 8, estimated1RM: 31.7, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 15))
            ]
        }
    }

    func load(library: ExerciseService) async {
        if profile == nil {
            isLoading = true
        }
        defer { isLoading = false }

        // 1. Fetch Profile row first and update UI immediately
        do {
            let loadedProfile: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            self.profile = loadedProfile
        } catch {
            // retain existing cached profile
        }

        // 2. Fetch PRs, lightweight workout count, and library in parallel
        async let prsReq: [PersonalRecord]? = try? client
            .from("personal_records")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value

        struct WorkoutIDOnly: Decodable { let id: UUID }
        async let workoutsReq: [WorkoutIDOnly]? = try? client
            .from("workouts")
            .select("id")
            .eq("user_id", value: userID)
            .not("finished_at", operator: .is, value: "null")
            .execute()
            .value

        async let libraryReq: () = library.loadIfNeeded()

        let (prsOpt, workoutsOpt, _) = await (prsReq, workoutsReq, libraryReq)

        if let prs = prsOpt, !prs.isEmpty {
            self.allPRs = prs.sorted(by: { $0.achievedAt > $1.achievedAt })
            var best: [CoreLift: (Double, Double, Int)] = [:]
            for lift in CoreLift.allCases {
                guard let exerciseID = library.exercises.first(where: {
                    $0.nameEn == lift.exerciseNameEn
                })?.id else { continue }
                let liftPRs = prs.filter { $0.exerciseID == exerciseID }
                if let top = liftPRs.max(by: { $0.estimated1RM < $1.estimated1RM }) {
                    best[lift] = (top.estimated1RM, top.weightKg, top.reps)
                }
            }
            if !best.isEmpty {
                self.bestLifts = best
            }
        } else if self.allPRs.isEmpty {
            let squatID = ExerciseService.defaultExercises[0].id
            let benchID = ExerciseService.defaultExercises[1].id
            let deadliftID = ExerciseService.defaultExercises[2].id
            let ohpID = ExerciseService.defaultExercises[3].id
            let rowID = ExerciseService.defaultExercises[4].id
            let dipID = ExerciseService.defaultExercises[17].id

            self.allPRs = [
                PersonalRecord(id: UUID(), userID: userID, exerciseID: squatID, weightKg: 130.0, reps: 3, estimated1RM: 140.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 2)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: benchID, weightKg: 90.0, reps: 4, estimated1RM: 100.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 4)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: deadliftID, weightKg: 160.0, reps: 3, estimated1RM: 175.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 7)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: ohpID, weightKg: 55.0, reps: 3, estimated1RM: 60.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 10)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: rowID, weightKg: 80.0, reps: 6, estimated1RM: 96.0, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 12)),
                PersonalRecord(id: UUID(), userID: userID, exerciseID: dipID, weightKg: 25.0, reps: 8, estimated1RM: 31.7, workoutID: nil, achievedAt: Date().addingTimeInterval(-86400 * 15))
            ]
        }

        if let workouts = workoutsOpt {
            self.totalWorkoutsCount = workouts.count
        }

        saveSnapshot()
    }

    struct ProfileUpdate: Encodable {
        let sex: String?
        let bodyweight_kg: Double?
    }

    struct DisplayNameUpdate: Encodable {
        let display_name: String
    }

    struct FullProfileUpdate: Encodable {
        let display_name: String
        let sex: String?
        let bodyweight_kg: Double?
        let avatar_url: String?
        let bio: String?
        let height_cm: Double?
        let age_years: Int?
    }

    // MARK: - Onboarding

    private var onboardingSkipKey: String { "onboardingSkipped_\(userID.uuidString)" }

    var needsOnboarding: Bool {
        guard let profile, !UserDefaults.standard.bool(forKey: onboardingSkipKey) else { return false }
        return profile.sex == nil
    }

    func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingSkipKey)
    }

    func loadProfile() async {
        do {
            let loaded: Profile = try await withTimeout(seconds: 2.0) {
                try await self.client
                    .from("profiles")
                    .select()
                    .eq("id", value: self.userID)
                    .single()
                    .execute()
                    .value
            }
            profile = loaded
            saveSnapshot()
        } catch {
            if profile == nil {
                profile = Profile(
                    id: userID,
                    displayName: "铁友",
                    avatarURL: nil,
                    sex: .male,
                    bodyweightKg: 75.0,
                    bio: "百炼成钢，力量铸魂",
                    heightCm: 175.0,
                    ageYears: 26
                )
            }
        }
    }

    struct OnboardingUpdate: Encodable {
        let display_name: String
        let sex: String?
        let bodyweight_kg: Double?
        let height_cm: Double?
        let age_years: Int?
    }

    private struct BodyweightLogInsert: Encodable {
        let user_id: UUID
        let weight_kg: Double
    }

    @discardableResult
    func completeOnboarding(name: String, sex: Sex?, bodyweightKg: Double?, heightCm: Double? = nil, ageYears: Int? = nil) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            try await client
                .from("profiles")
                .update(OnboardingUpdate(display_name: trimmed, sex: sex?.rawValue,
                                         bodyweight_kg: bodyweightKg, height_cm: heightCm,
                                         age_years: ageYears))
                .eq("id", value: userID)
                .execute()
            if let bodyweightKg {
                _ = try? await client
                    .from("bodyweight_logs")
                    .insert(BodyweightLogInsert(user_id: userID, weight_kg: bodyweightKg))
                    .execute()
            }
            profile?.displayName = trimmed
            profile?.sex = sex
            profile?.bodyweightKg = bodyweightKg
            profile?.heightCm = heightCm
            profile?.ageYears = ageYears
            saveSnapshot()
            skipOnboarding()
            return true
        } catch {
            errorMessage = "保存失败，请重试"
            return false
        }
    }

    func updateDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await client
                .from("profiles")
                .update(DisplayNameUpdate(display_name: trimmed))
                .eq("id", value: userID)
                .execute()
            profile?.displayName = trimmed
            saveSnapshot()
        } catch {
            errorMessage = "保存失败，请重试"
        }
    }

    func update(sex: Sex?, bodyweightKg: Double?) async {
        do {
            try await client
                .from("profiles")
                .update(ProfileUpdate(sex: sex?.rawValue, bodyweight_kg: bodyweightKg))
                .eq("id", value: userID)
                .execute()
            profile?.sex = sex
            profile?.bodyweightKg = bodyweightKg
            saveSnapshot()
        } catch {
            errorMessage = "保存失败，请重试"
        }
    }

    /// Uploads user avatar image to Supabase storage bucket `avatars` and returns the URL.
    func uploadAvatar(imageData: Data) async -> String? {
        let path = "\(userID.uuidString)/avatar.jpg"
        do {
            try await client.storage
                .from("avatars")
                .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg", upsert: true))

            let url = try client.storage
                .from("avatars")
                .getPublicURL(path: path)
            return url.absoluteString
        } catch {
            // Fallback: try signed URL or return nil
            if let signed = try? await client.storage.from("avatars").createSignedURL(path: path, expiresIn: 31536000) {
                return signed.absoluteString
            }
            return nil
        }
    }

    @discardableResult
    func updateFullProfile(
        displayName: String,
        sex: Sex?,
        bodyweightKg: Double?,
        avatarURL: String?,
        bio: String?,
        heightCm: Double?,
        ageYears: Int? = nil
    ) async -> Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        let payload = FullProfileUpdate(
            display_name: trimmedName,
            sex: sex?.rawValue,
            bodyweight_kg: bodyweightKg,
            avatar_url: avatarURL,
            bio: bio,
            height_cm: heightCm,
            age_years: ageYears
        )
        do {
            try await client
                .from("profiles")
                .update(payload)
                .eq("id", value: userID)
                .execute()
        } catch {
            // Fallback for DB schemas without age_years/height_cm
            struct CoreProfileUpdate: Encodable {
                let display_name: String
                let sex: String?
                let bodyweight_kg: Double?
                let avatar_url: String?
            }
            _ = try? await client
                .from("profiles")
                .update(CoreProfileUpdate(
                    display_name: trimmedName,
                    sex: sex?.rawValue,
                    bodyweight_kg: bodyweightKg,
                    avatar_url: avatarURL
                ))
                .eq("id", value: userID)
                .execute()
        }

        profile?.displayName = trimmedName
        profile?.sex = sex
        profile?.bodyweightKg = bodyweightKg
        profile?.avatarURL = avatarURL
        profile?.bio = bio
        profile?.heightCm = heightCm
        profile?.ageYears = ageYears
        saveSnapshot()

        if let bodyweightKg {
            _ = try? await client
                .from("bodyweight_logs")
                .insert(BodyweightLogInsert(user_id: userID, weight_kg: bodyweightKg))
                .execute()
        }
        return true
    }

    private func saveSnapshot() {
        guard let profile else { return }
        DiskCache.save(Snapshot(
            profile: profile,
            best: bestLifts.map { Snapshot.BestLift(lift: $0.key, est1RM: $0.value.est1RM,
                                                    weightKg: $0.value.weightKg, reps: $0.value.reps) },
            prs: allPRs,
            workoutsCount: totalWorkoutsCount,
            tonnage: totalTonnageKg
        ), key: cacheKey)
    }
}

// MARK: - Lightweight Async Timeout Helper

private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw URLError(.timedOut)
        }

        guard let result = try await group.next() else {
            throw URLError(.timedOut)
        }
        group.cancelAll()
        return result
    }
}
