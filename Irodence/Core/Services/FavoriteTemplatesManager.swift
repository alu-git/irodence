import Foundation
import SwiftUI

/// Manages favorited / pinned templates for quick 1-tap access on the Workout Home Screen.
@MainActor
final class FavoriteTemplatesManager: ObservableObject {
    static let shared = FavoriteTemplatesManager()

    private let storageKey = "irodence_favorite_template_ids_v1"

    @Published private(set) var favoriteIDs: Set<String> = []

    init() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            favoriteIDs = Set(saved)
        } else {
            // Default initial favorites: Push Day and Big 3
            favoriteIDs = ["ppl_push_strength", "sbd_big_three"]
            save()
        }
    }

    func isFavorite(id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    func toggleFavorite(id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        save()
    }

    func setFavorite(id: String, isFavorite: Bool) {
        if isFavorite {
            favoriteIDs.insert(id)
        } else {
            favoriteIDs.remove(id)
        }
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(favoriteIDs), forKey: storageKey)
    }
}
