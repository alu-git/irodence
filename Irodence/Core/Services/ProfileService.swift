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

    init(userID: UUID) {
        self.userID = userID
    }

    func load(library: ExerciseService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .single()
                .execute()
                .value

            await library.loadIfNeeded()
            let prs: [PersonalRecord] = try await client
                .from("personal_records")
                .select()
                .eq("user_id", value: userID)
                .execute()
                .value

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
        } catch {
            errorMessage = "加载个人资料失败"
        }
    }

    struct ProfileUpdate: Encodable {
        let sex: String?
        let bodyweight_kg: Double?
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
        } catch {
            errorMessage = "保存失败，请重试"
        }
    }
}
