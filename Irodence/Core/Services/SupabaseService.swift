import Foundation
import Supabase

/// Shared Supabase client. Row-level security enforces per-user access
/// server-side; the anon key alone cannot read other users' data.
enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
