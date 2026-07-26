import Foundation
import Supabase

/// Profile data + the user's PRs for strength-standard calculations.
@MainActor
final class ProfileService: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var bestLifts: [CoreLift: (est1RM: Double, weightKg: Double, reps: Int)] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseService.client
    private let userID: UUID

    /// Codable snapshot of what the profile tab renders (bestLifts uses
    /// tuples internally, which aren't Codable — hence the flat struct).
    private struct Snapshot: Codable {
        struct BestLift: Codable {
            let lift: CoreLift
            let est1RM: Double
            let weightKg: Double
            let reps: Int
        }
        let profile: Profile
        let best: [BestLift]
    }

    private var cacheKey: String { "profile_\(userID.uuidString)" }

    init(userID: UUID) {
        self.userID = userID
        // Render instantly from the last snapshot; load() refreshes silently.
        if let snapshot: Snapshot = DiskCache.load(Snapshot.self, key: cacheKey) {
            profile = snapshot.profile
            bestLifts = Dictionary(
                uniqueKeysWithValues: snapshot.best.map {
                    ($0.lift, (est1RM: $0.est1RM, weightKg: $0.weightKg, reps: $0.reps))
                }
            )
        }
    }

    func load(library: ExerciseService) async {
        isLoading = true
        defer { isLoading = false }

        // Fire profile, PRs, and the library refresh CONCURRENTLY — they are
        // independent and used to run one-after-another.
        async let profileReq: Profile = client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
        async let prsReq: [PersonalRecord] = client
            .from("personal_records")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value
        async let libraryReq: () = library.loadIfNeeded()

        do {
            let (loadedProfile, prs, _) = try await (profileReq, prsReq, libraryReq)
            profile = loadedProfile

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
            bestLifts = best
            saveSnapshot()
        } catch {
            // Keep showing the cached snapshot; only complain with nothing to show
            if profile == nil {
                errorMessage = "加载个人资料失败"
            }
        }
    }

    struct ProfileUpdate: Encodable {
        let sex: String?
        let bodyweight_kg: Double?
    }

    struct DisplayNameUpdate: Encodable {
        let display_name: String
    }

    // MARK: - Onboarding

    /// Keyed per user so a second account on the same device still gets onboarding.
    private var onboardingSkipKey: String { "onboardingSkipped_\(userID.uuidString)" }

    /// True for brand-new accounts (the DB trigger creates the row with no
    /// sex set) that haven't finished or dismissed onboarding on this device.
    var needsOnboarding: Bool {
        guard let profile, !UserDefaults.standard.bool(forKey: onboardingSkipKey) else { return false }
        return profile.sex == nil
    }

    func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingSkipKey)
    }

    /// Fetches just the profile row — used by the onboarding gate before the
    /// full load(library:) runs. On failure the cached snapshot (applied in
    /// init) stays in place and the gate fails open.
    func loadProfile() async {
        do {
            let loaded: Profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            profile = loaded
            saveSnapshot()
        } catch {
            if profile == nil {
                errorMessage = "加载个人资料失败"
            }
        }
    }

    struct OnboardingUpdate: Encodable {
        let display_name: String
        let sex: String?
        let bodyweight_kg: Double?
    }

    private struct BodyweightLogInsert: Encodable {
        let user_id: UUID
        let weight_kg: Double
    }

    /// One-shot save at the end of onboarding: display name + sex + bodyweight
    /// in a single update (nil sex/bodyweight are omitted, leaving the column
    /// untouched). Also seeds bodyweight_logs (best effort) so the weight
    /// chart has its first point.
    @discardableResult
    func completeOnboarding(name: String, sex: Sex?, bodyweightKg: Double?) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            try await client
                .from("profiles")
                .update(OnboardingUpdate(display_name: trimmed, sex: sex?.rawValue,
                                         bodyweight_kg: bodyweightKg))
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

    private func saveSnapshot() {
        guard let profile else { return }
        DiskCache.save(Snapshot(
            profile: profile,
            best: bestLifts.map { Snapshot.BestLift(lift: $0.key, est1RM: $0.value.est1RM,
                                                    weightKg: $0.value.weightKg, reps: $0.value.reps) }
        ), key: cacheKey)
    }
}
